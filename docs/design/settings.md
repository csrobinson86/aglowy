# Settings

One Settings page for everything a person can change: their own settings first ("You"), then the household's. It replaces the two pages we have now, account settings at `/account` and Household settings at `/:household_id/settings`. Stories live under the **SETTINGS-01** epic.

Frames in `docs/design/settings/` (README there). Mockups are in the "Settings (combined)" row on the design canvas.

## Decisions (Casey, 16 Nov)

- **One Settings page instead of two.** A single "Settings" item in the sidebar footer, for everyone, replaces "Household settings" and the link on the person's name.
- **A page per section,** not one long page. A section nav on the left switches between them. On a phone it's a menu above the section.
- **"Tags and collections" joins the "You" part,** so tags and collections are managed in one place.

## Sections and who sees them

| Group | Section | Head | Adult | Child | What's on it |
| --- | --- | --- | --- | --- | --- |
| You | Profile | yes | yes | yes | Name, your time zone |
| You | Appearance | yes | yes | yes | Theme: Match my device, Light, Dark (`docs/design/app-shell.md`, Theming and appearance) |
| You | Signing in | yes | yes | password only, username read-only | Email, new password, current password (`docs/design/invitations.md`) |
| You | My households | yes | yes | yes, without Leave | Each household with the person's role, and Leave |
| You | Tags and collections | yes | yes | yes | Rename and delete tags; edit and delete collections |
| You | Calendar | yes | yes | yes | Share my times with a household; the phone calendar link (`docs/design/calendar.md`, CAL-01) |
| The household's name | Household | yes | no | no | Name, time zone |
| | Meetings | yes | yes | no | Midweek and weekend meeting times (`docs/design/meeting-helper.md`) |
| | Children | yes | yes, meeting helper only | no | The meeting helper switch; "Personal study with AI" per child, heads only (`docs/design/personal-study.md`, Children) |
| | Members and roles | yes | no | no | Each member's role, and Remove |

- The household group's heading is the household's name ("Rivera household"), because these settings belong to that household and nobody else's.
- A child sees only the "You" group. The household group is hidden, not greyed out.
- Hiding a link is not authorization. Each section's controller authorizes, as today, and a refusal goes through `not_authorized` ("You can't do that in this household.").
- The "You" sections are the same person from any household. The household group is always the household in the URL.

## Pages and routes

Every section is its own page under `/:household_id/settings`, in the household layout. Frames: `settings-profile.png`, `settings-tags.png`, `settings-members.png`, `settings-adult-meetings.png`, `settings-child.png`, `settings-appearance-dark.png`.

```ruby
# Inside the existing household scope.
scope "/:household_id", as: :household do
  # Settings opens on Profile, for everyone.
  get "settings", to: redirect("/%{household_id}/settings/profile"), as: :settings

  namespace :settings do
    resource :profile, only: %i[ show update ]
    resource :appearance, only: %i[ show update ]
    resource :sign_in, only: %i[ show update ]
    resources :memberships, only: %i[ index destroy ]   # My households
    resources :tags, only: :index                       # Tags and collections
    resource :household, only: %i[ show update ]
    resource :meetings, only: %i[ show update ]
    resource :children, only: :show
    resource :meeting_helper, only: :update
    resources :members, only: :index                    # Members and roles
  end
end
```

| Section | Page | Saves to | Replaces |
| --- | --- | --- | --- |
| Profile | `Settings::ProfilesController#show` | `#update`, `@user.update(name:, time_zone:)` | the Profile box on `/account` |
| Appearance | `Settings::AppearancesController#show` | `#update`, `@user.update(appearance:)` | `PATCH /account/appearance` from a household |
| Signing in | `Settings::SignInsController#show` | `#update`, `identity.update_with_password` | `/account/sign_in` from a household |
| My households | `Settings::MembershipsController#index` | `#destroy`, `membership.deactivate` | `DELETE /account/memberships/:id` from a household |
| Tags and collections | `Settings::TagsController#index` | the existing `PATCH`/`DELETE /:household_id/tags/:name` and `/:household_id/collections/:id` | `GET /:household_id/tags` (My tags) |
| Household | `Settings::HouseholdsController#show` | `#update`, `household.update_settings` | `Households::SettingsController` |
| Meetings | `Settings::MeetingsController#show` | `#update`, `household.change_meeting_times` | `Households::MeetingTimesController` |
| Children | `Settings::ChildrenController#show` | `Settings::MeetingHelpersController#update`; the study AI grant's own route (#203) | `Households::MeetingHelpersController` |
| Members and roles | `Settings::MembersController#index` | the existing `Members::RolesController#update` (Turbo Stream, unchanged) and `MembersController#destroy` | the Members and roles box |

- **Each save returns to its own section,** with the same notices as today ("Your profile is saved.", "Meeting times saved.", …). A refused save re-renders that section with `:unprocessable_content`, so Primer shows the error by the field.
- **Leaving.** Leaving the household in the URL goes to the households page, as today. Leaving another household returns to My households. The last head is refused with "Make someone else a head before you leave."
- **Losing access mid-page.** A head who makes themselves an adult already goes to Home (`Members::RolesController`). Keep that.
- **The models don't change.** Every save calls the model method it calls today. The controllers move; the logic doesn't.
- **Moved controllers are deleted,** with their routes: `Households::SettingsController`, `Households::MeetingTimesController`, `Households::MeetingHelpersController`, and `TagsController#index`. Every link to them points at the new section (for example Home's "Set your meeting times" goes to Meetings).

### `/account` stays, for people with no household

A person can leave every household they're in (`docs/design/invitations.md`). They still need to change their name and password, so `/account` stays in the focused layout, unchanged except:
- `GET /account` redirects to `/:household_id/settings/profile` when the person has an active household (the first by name).
- `return_to` and "Back to <household>" go away, since only people with no household see the page now.
- Its saves stay as they are, returning to `/account`.

## The page

`Settings::PageComponent` draws every section page: the `h1` "Settings" in a Primer `Subhead`, the section nav, then the section's title as an `h2` with a one-line note, then the section's content (`with_body`). Section views render inside it and hold only their own boxes.

| Section | Note under the title |
| --- | --- |
| Profile | Follows you to every household. |
| Appearance | Follows you to every household and device. |
| Signing in | How you sign in to Aglowy. |
| My households | The households you belong to. |
| Tags and collections | Rename or delete your tags and collections. Only you see them. |
| Calendar | Who sees your times, and your phone calendar link. |
| Household | Rivera household · heads can change this. |
| Meetings | Rivera household · heads and adults can change this. |
| Children | Rivera household · heads and adults; AI for a child is heads only. |
| Members and roles | Rivera household · heads only. |

The section boxes are today's boxes, moved as they are: the same Primer `BorderBox`es, form classes (`Accounts::ProfileForm`, `Accounts::AppearanceForm`, `Accounts::SignInForm`, `Households::SettingsForm`, `Households::MeetingTimesForm`, `Households::MeetingHelperForm`) and partials (`households/settings/_member`, `accounts/_households`). Move them into `app/forms/settings/` and `app/views/settings/` as you go, so nothing is left under the old names.

### The section nav

`Settings::NavComponent`, a Primer `NavList` labelled "Settings" (`aria: { label: "Settings" }`), with two groups:
- "You": Profile, Appearance, Signing in, My households, Tags and collections, then Calendar once CAL-01 adds it (`docs/design/calendar.md`, Settings → Calendar, which has its routes)
- the household's name: the sections the person's role allows, in the table's order. No group at all for a child.

The current section is selected (`aria-current="page"`, from Primer). Each section's controller passes its id (`:profile`, `:meetings`, …).

### On a phone

Below Primer's `md` breakpoint (frames `phone-settings.png` and `phone-settings-menu.png`), the nav becomes a full-width Primer `ActionMenu` button above the section, labelled with the current section ("Appearance"):
- `select_variant: :single`, the current section checked, each item a link to its page
- the same two groups, with their headings. If `ActionMenu` in the pinned `primer_view_components` has no `with_group`, use a divider and a heading item, and note it here
- the button is at least 44 px tall

### The sidebar

- **Footer:** "Settings" (Octicon `gear`) for everyone, then the person's initial and name, now plain text, with Sign out. "Household settings" goes away.
- **Selected on every settings page.** Settings controllers live under `Settings::`, so the shell selects "Settings" when `controller_path` starts with `settings/`, rather than by `controller_name`.

## Tags and collections

Frame `settings-tags.png`. Built after PSTUDY-01's first story (#199), which adds `Collection`.

- **My tags:** today's My tags list, moved here. Each tag links to its page (`/:household_id/tags/:name`) with its count and where it's used, then Rename (a Primer `Dialog` with the existing rename form) and Delete (a `Dialog` that says what happens). Renaming and deleting post to the existing `TagsController` actions, which now return to this section. The empty state: "No tags yet. Add a tag from a meeting note, a goal, a study or a note."
- **Collections:** the person's collections (`Current.user.collections`), each with its counts ("6 notes, 4 studies") and "Used in Notes and Personal study" (or "Personal study only", "Notes only"). Then:
  - **Edit:** a `Dialog` with a Primer form holding Name and "Use in" (both, Personal study only, Notes only). It posts to `PATCH /:household_id/collections/:id` (from #199), which keeps its rule: moving `used_in` away from a section that still has things in the collection is refused with "3 notes are in this collection. Move them first."
  - **Delete:** a `Dialog` ("Everything in it stays; it just leaves the folder."), then `DELETE /:household_id/collections/:id`.
  - New collections are still made from Personal study or Notes. The line under the list says so.
- **`household_tags_path` goes away with `TagsController#index`.** The tag page's breadcrumb ("Tags and collections", in place of "My tags") and the redirects after rename and delete in `TagsController` all use `household_settings_tags_path`. Search for any other caller before removing the route.
- Both lists come from `Current.user`, so another person's tag or collection is a 404.

## Traps

- **Look the household up through `Current.user`,** as `HouseholdScoped` does. Settings pages are household pages.
- **The "You" sections save the person, never `Current.membership`.** Policies for them read the user, not the role (a child can change their own password).
- **Don't build a second copy of a form.** Profile, Appearance and Signing in render the same form classes on `/account` and in Settings.
- **One redirect per section.** Each controller redirects to its own section's path. Don't use `redirect_back`: the referer may be missing.
- **Keep the last-head guard** on roles, Remove and Leave. It's in the models; don't route around it.

## States each story checks

- Head, adult, child; a non-member (404)
- Every section the role allows; a section it doesn't (refused, and missing from the nav)
- A save that works and one that's refused, for each form
- Leaving this household, another household, as the last head (refused), as a child (refused)
- `/account` with and without an active household
- Desktop and phone; light and dark
