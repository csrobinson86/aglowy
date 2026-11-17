# Avatars

A person can show a photo of themselves wherever Aglowy shows them, or keep their initial in a color they pick. Stories live under the **AVATAR-01** epic.

Frames in `docs/design/avatars/` (README there). Mockups are in the "Avatars" row on the design canvas.

## Decisions (Casey, 16 Nov)

- **A photo, or your initial in a color you pick.** There are no ready-made illustrated avatars.
- **Children too.** A child who signs in changes their own avatar. Heads and adults set any child's avatar in Settings → Children, which is how a child without a login gets one.
- **Aglowy crops the photo itself.** It keeps the middle square and shows a preview before saving. There's no drag-and-zoom crop tool.

What follows from these, and needs Casey's OK in the PR:
- **libvips in the image.** Cropping, resizing and removing a photo's location data happen on the server with the `image_processing` gem and libvips. That's a new system library in the Docker image, used only for avatars (Active Storage variants stay off).
- **A sixth approved hand-built form element:** the photo picker. Primer Forms has no file input, so it's a real labelled `<input type="file">` inside a Primer form, opened by a Primer `Button`, like the file drop zone. The color choice reuses the note color picker (approved exception 5), generalized to take any palette.

## What an avatar is

Every person has one, whether or not they log in:
- **a photo**, when one has been saved: always a 256 × 256 WebP that Aglowy made, with no location or camera details, or
- **their initial**, the first letter of their name, on a circle in their color. Blue unless they pick another.

Everyone who shares an active household with a person sees their avatar. It's the same in every household, because it belongs to the person (`User`), not the seat.

## Who can do what

| Action | The person | Head or adult in a household the child is in | Anyone else |
| --- | --- | --- | --- |
| Change or remove their own photo, pick their color | yes, children who sign in too | | |
| Change or remove a child's photo, pick a child's color | | yes | no |
| Change another adult's or head's avatar | | no | no |
| See an avatar | yes | yes, members of a shared active household | no (404) |

- A child in two households (two homes) can have their avatar changed by heads and adults in either. The latest change wins.
- Staff see no avatars in Madmin. Don't add `avatar` to Madmin's user resource.

## Models

### `User`

| Column or attachment | Type | Constraint | Why |
| --- | --- | --- | --- |
| `avatar_color` | string | not null, default `blue`; check in (`blue`, `green`, `purple`, `pink`, `orange`, `yellow`) | The initial's color: the same six hues as notes, minus "none" |
| `avatar` | `has_one_attached` | WebP only, at most 100 KB (validation) | Only ever the image Aglowy made, never the upload |

- **`user.change_avatar(file)`** takes the uploaded file (an `ActionDispatch::Http::UploadedFile`), checks it and builds the avatar before anything is stored:
  1. **Check:** `Marcel::MimeType.for(file)` (from the bytes, not the name or the browser's type) is one of `image/jpeg`, `image/png`, `image/webp`, `image/heic`, `image/heif`; the file is at most 10 MB; libvips can read its header; and it's at least 64 × 64 and at most 50 megapixels. Any failure adds `:avatar` errors and returns false: "Choose a JPEG, PNG, WebP or HEIC photo up to 10 MB."
  2. **Build:** `ImageProcessing::Vips.source(file.tempfile).autorot.resize_to_fill(256, 256, crop: :centre).convert("webp").saver(strip: true, quality: 80).call`. `autorot` turns phone photos upright before the location data is stripped.
  3. **Store:** attach the result as `avatar` (`avatar.webp`). The upload itself is never attached, so the original photo and its location never reach storage.
- **`user.remove_avatar`**: `avatar.purge`. The initial shows again.
- **`user.change_avatar_color(color)`**: `update(avatar_color: color)`.
- **`user.visible_to?(viewer)`**: true for the viewer themselves, or when they share an active household: one query, `Membership.active.where(user: viewer).where(household_id: memberships.active.select(:household_id)).exists?`.
- Processing runs in the request. A 10 MB photo takes well under a second with libvips, and there's no half-made state to show.

### `Avatar::Palette`

The six colors and their Primer display primitives (`--display-<color>-bgColor-muted` for the circle and `--display-<color>-fgColor` for the letter), in one place for the component and the color picker. Dark mode comes from Primer.

## Pages and routes

```ruby
# Inside the household scope.
namespace :settings do
  resource :avatar, only: %i[ update destroy ]               # your own: photo and color
  resources :children, only: [] do
    resource :avatar, only: %i[ update destroy ], module: :children   # a child's, heads and adults
  end
end

# Outside the household scope: one URL per person, used on every page.
get "people/:user_id/avatar", to: "avatars#show", as: :avatar
```

| What | Route | Frame |
| --- | --- | --- |
| Your avatar, in Settings → Profile | the Profile section, a new "Avatar" box above "Profile" | `settings-avatar.png`, `settings-avatar-photo.png`, `settings-avatar-dark.png` |
| Save a photo or a color | `PATCH /:household_id/settings/avatar` (`Settings::AvatarsController#update`, with `avatar[photo]` or `avatar[color]`) | `avatar-preview.png` |
| Remove the photo | `DELETE /:household_id/settings/avatar` | |
| A child's avatar | Settings → Children, a new "Children's avatars" box; `PATCH`/`DELETE /:household_id/settings/children/:child_id/avatar` | `settings-children-avatars.png`, `child-avatar-preview.png` |
| A child's own | Settings → Profile, as above | `child-profile-avatar.png` |
| The image | `GET /people/:user_id/avatar` (`AvatarsController#show`) | |
| On a phone | the same pages | `phone-avatar.png` |

- Each save returns to its own section with a notice ("Your avatar is saved.", "Sofia's avatar is saved.", "Your photo is removed."). A refused photo re-renders the section with `:unprocessable_content` and the error under the picker.
- `/account` (people with no household) shows the avatar but doesn't change it. Changing it needs a household page, like the other settings that moved.

### The Avatar box (Settings → Profile)

- The avatar at 80 px, then:
  - **"Upload photo"** (or **"Change photo"** when there is one): a Primer `Button` that opens the file picker (`accept="image/jpeg,image/png,image/webp,image/heic,image/heif"`; on a phone the picker offers the camera too).
  - **"Remove photo"** (danger, only with a photo), posting `DELETE`.
  - The caption: "JPEG, PNG, WebP or HEIC, up to 10 MB. Aglowy keeps the middle of the photo as a square and removes its location and camera details." and "Everyone in your households sees your avatar."
- **Color for your initial** (only without a photo): the generalized color picker (`ColorPickerComponent`), six swatches each drawing the person's initial, with the chosen color's name beside them, then "Save color".

### The preview dialog

Choosing a file opens a Primer `Dialog`, "New avatar" (or "Avatar for Sofia"):
- the chosen photo at 160 px in a circle, drawn by a small Stimulus controller from `URL.createObjectURL` with `object-fit: cover`. That is the same middle square the server keeps. Nothing is uploaded yet.
- the file's name and size; over 10 MB, the error shows here at once and Save is disabled
- "Choose another photo"
- the line "This is how it will look. Aglowy keeps the middle as a square and removes the photo's location and camera details. Everyone in your households will see it." (for a child: "Everyone in Sofia's households will see it.")
- footer: Cancel, and "Save avatar" (primary), which submits the form with the file

A browser that can't draw the photo (HEIC on most desktops) shows "Preview not available for this photo. It will be cropped the same way." in place of the image, and Save still works: the server reads HEIC.

### Children's avatars (Settings → Children)

A "Children's avatars" box first in the section, for heads and adults: one row per child member, with their avatar, name, "Signs in as eli.rivera · can change it too" or "No login", and "Change avatar". That opens a dialog with the child's current avatar, "Upload photo", "Remove photo" (when there's one) and their color picker; choosing a photo shows the same preview. The note under the list: "A child's avatar follows them to every household they're in. Children who sign in can change their own in Settings → Profile."

`Settings::Children::AvatarsController` finds the child through `Current.household.memberships.active.child.find_by!(user_id: params[:child_id]).user`, so an adult in the household or a child elsewhere is a 404. `AvatarPolicy#update?` is head or adult.

`Settings::AvatarsController` (your own avatar) always works on `Current.user` and never takes a user id. `AvatarPolicy#update_own?` is any active member, children included, so a child who signs in can change theirs. Keep the two rules apart: never reuse `update?` (head or adult) for your own avatar.

### `AvatarComponent`

`AvatarComponent.new(user:, size: 24)` replaces the six hand-written initial circles (the sidebar footer, Members, Settings → Members and roles, Settings → Children, goal steps and rows, goal progress). It draws:
- with a photo: Primer `Avatar` (`Primer::Beta::Avatar`, `shape: :circle`, `size:`) with `src: avatar_path(user, v: user.avatar.blob.checksum)` and `alt: ""` beside a visible name, or `alt: user.name` when it stands alone
- without: the initial in `.avatar-initial--<color>` (BEM Sass from `Avatar::Palette`), `aria-hidden` when the name is beside it

Sizes are Primer's (16, 20, 24, 32, 40, 48, 64, 80); 80 is Settings → Profile. The `v` parameter changes with each new photo, so a new photo is never confused with an old one in the browser's cache.

### Serving the image

`AvatarsController#show`, outside the household scope:
- `user = User.find(params[:user_id])`, then 404 unless `user.visible_to?(Current.user)` and `user.avatar.attached?`. Not finding and not seeing look the same.
- **The browser keeps it but asks every time:** `response.cache_control.merge!(private: true, no_cache: true)`, then `if stale?(user.avatar.blob, public: false)` … `send_data user.avatar.download, type: "image/webp", disposition: "inline"`. The visibility check runs on every request, so someone who leaves the household stops seeing the photo, and an unchanged photo costs only a `304 Not Modified` with no body. Never call `send_data` before `stale?`, or a fresh request raises a double render instead of sending the 304.
- The image is at most 100 KB, so it's streamed rather than redirected to a short-lived storage URL.
- `skip_after_action :verify_authorized` is not used: `authorize user, :show_avatar?` with `AvatarPolicy`, which reads `Current.user` (there's no membership outside a household).

## Elsewhere

- **`docs/design/settings.md`:** Profile gains the Avatar box; Children gains "Children's avatars".
- **`CLAUDE.md`:** the stack gains "`image_processing` with libvips, for avatars only"; the approved exceptions gain the photo picker, and the note color picker becomes the color picker used by notes and avatars.
- **Dockerfile:** the runtime stage installs `libvips42` (with HEIC support from `libheif1`); CI installs it too.
- **Seeds** (`db/seeds/08_avatars.rb`): every seeded person gets a color; one adult gets a photo made by libvips in the seed (a plain gradient, `Vips::Image` only, no stock photos and no download).

## Traps

1. **Never store the upload.** Process the tempfile and attach only the result. A photo of a child can carry the GPS location of the family's home.
2. **Check the bytes, not the name.** Use Marcel on the content and let libvips read the header before decoding. Refuse anything over 50 megapixels before it's decoded (a decompression bomb).
3. **`autorot` before `strip`.** Stripping first loses the orientation, and phone photos come out sideways.
4. **404, not 403,** for an avatar the viewer can't see, and for a child outside the household.
5. **Only children.** A head or adult can't change another adult's avatar, even a head's. The policy checks the target is a child here.
6. **Escape names,** and give the image `alt=""` when the name is already beside it, so a screen reader doesn't read it twice.
7. **Don't turn on Active Storage variants.** The stored avatar is already the size served; CSS draws it smaller.

## States each story checks

- Head, adult, child with a login, child without a login; a non-member (404)
- No photo in each color; a photo; removing it
- A JPEG with location data (gone after), a sideways phone photo (upright), PNG, WebP, HEIC; a PDF renamed `.jpg`, 11 MB, 40 × 40, 60 megapixels (all refused)
- A head changing a child's avatar; an adult trying another adult's (404); a child in two households
- Another household's member's avatar URL (404)
- Desktop and phone; light and dark
