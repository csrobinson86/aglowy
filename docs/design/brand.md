# Brand

Aglowy's logo, where it appears, and the files to use. Stories live under the **BRAND-01** epic.

The mark and its sizes are in `docs/design/brand/logo.png`, and in the "Logo" row on the design canvas.

## Decision (Casey, 17 Nov)

**Two flames.** A large flame and a small one side by side: a parent and a child, aglow together (*"Aglow with the spirit,"* Romans 12:11). It replaces the Octicon `sun` that stood in for a mark.

**Centred above the sign-in form.** On the sign-in page the logo sits in the middle of the page, above the form, not in the top-left corner. The same goes for every page a signed-out person sees (below), so moving between Sign in and Create an account doesn't move the logo.

## The logo

- **The mark** is three flame shapes in warm colours, with no dark parts, so the same file works on light and dark backgrounds. There's no dark variant of the mark.
- **The wordmark** is "Aglowy" in Mona Sans SemiBold (GitHub's typeface, SIL Open Font License). In the lockup files the letters are outlines, so they need no font.
- **In the app, the name stays text.** Pages show the mark as an image beside the word "Aglowy" in Primer's own type and colour, so it follows light and dark and a screen reader reads it once. The lockup SVGs are for places outside the app: a README, a slide, a social card.

### Colours

These hex values live only in the logo files. The app's CSS never uses them; it keeps Primer's primitives (`CLAUDE.md`).

| Name | Hex | Where |
| --- | --- | --- |
| Ember | `#C9541E` | The large flame |
| Amber | `#E8871E` | The inner flame |
| Gold | `#F2A93B` | The small flame |
| Ink | `#1F2328` | The app icon's ground, the manifest's `theme_color` and `background_color`, and the wordmark on light (Primer's `fgColor-default`) |
| Paper | `#F6F8FA` | The wordmark on dark |

### Using it

- The mark is never smaller than 16 px, and it keeps clear space of half its height on every side.
- Don't recolour it, outline it, put it on a photo, or add the old sun beside it.
- The Octicon `sun` that marks today's meeting (the Home card, the sidebar's "Today's meeting", the meeting summary) stays. It means the meeting, not Aglowy.

## Files

In `docs/design/brand/`. The story copies them to where the app serves them.

| File | What it is | Goes to |
| --- | --- | --- |
| `aglowy-mark.svg` | The mark, 64 × 64, transparent | `app/assets/images/aglowy-mark.svg` and `public/icon.svg` (the favicon) |
| `favicon-32.png` | The mark at 32 px, transparent | `public/icon.png`, the PNG favicon for browsers without SVG favicons |
| `aglowy-app-icon-maskable.svg` | The mark on ink, full bleed, inside the 80% safe zone | The source of the three PNGs below |
| `icon-512.png`, `icon-192.png` | The app icon for the web app manifest (`any` and `maskable`) | `public/icon-512.png`, `public/icon-192.png` |
| `apple-touch-icon.png` | 180 px, for an iPhone's Home Screen (iOS rounds the corners) | `public/apple-touch-icon.png` |
| `mark-128.png` | The mark at 128 px, transparent | Kept for emails: `docs/design/notifications.md` allows "the Aglowy mark" in email |
| `aglowy-app-icon.svg` | The app icon with rounded corners | For mockups and slides only |
| `aglowy-lockup.svg`, `aglowy-lockup-dark.svg` | Mark and wordmark, on light and on dark | Outside the app only |

## Where it appears

| Place | Today | Becomes |
| --- | --- | --- |
| Sidebar, top (and the phone menu, which is the same sidebar) | Octicon `sun` + "Aglowy" | `LogoComponent` |
| Phone top bar, in a household (`docs/design/app-shell.md`, Phone; Casey, 21 Nov) | The household switcher | `LogoComponent` `size: :small`: the mark alone, 24 px, left-aligned right after the menu button |
| `focused` layout, signed out: sign in, create an account, password reset, confirmation, accepting an invitation as someone new, a child choosing a password | Octicon `sun` + "Aglowy" at the top left | `LogoComponent` `size: :large`: the mark alone, 48 px, centred above the page's heading (frames `app-shell/sign-in.png`, `app-shell/phone-sign-in.png`, `invitations/accept-new-account.png`) |
| `focused` layout, signed in: the household chooser, new household, account settings, accepting an invitation with an account | Octicon `sun` + "Aglowy" at the top left | `LogoComponent` at the top left, as now (frame `invitations/accept-existing-account.png`) |
| `shared/_header` (the `application` layout) | "Aglowy" | `LogoComponent` |
| Browser tab | Rails' placeholder red circle | `public/icon.svg`, with `public/icon.png` as the PNG fallback |
| iPhone Home Screen | The red circle | `public/apple-touch-icon.png` |
| Web app manifest (`app/views/pwa/manifest.json.erb`) | The red circle, `theme_color: "red"` | `icon-192.png` and `icon-512.png`, both colours `#1F2328`, the description from `docs/product/vision.md` |

**`LogoComponent.new(href:, size: :medium)`** has three sizes:

- **`:medium`** (the default): a Primer `Link` (`scheme: :primary`, bold, `font_size: 3`, no underline) holding `image_tag("aglowy-mark.svg", alt: "", width: 24, height: 24)` and the text "Aglowy". The image's `alt` is empty because the word beside it already names the link.
- **`:small`**: the same link holding only the mark at 24 × 24, with `alt: "Aglowy"`, because the image is the link's whole name. For the phone top bar, where the word wouldn't fit beside the menu button and the bell. The link is at least 44 px square, for touch, with the mark centred in it and its clear space kept.
- **`:large`**: the same link holding only the mark at 48 × 48, with `alt: "Aglowy"`, because the image is now the link's whole name. The page's own heading follows it ("Sign in to Aglowy", "Create your account"), so the word isn't repeated beside the mark.

**The `focused` layout picks by sign-in state,** not by page: `identity_signed_in?` shows the `:medium` logo in a top-left `<header>`; otherwise the `<header>` centres the `:large` logo above the column, 48 px from the top of the page and 24 px above the heading, on a phone as on a desktop. It's one `<header>` either way, so every page keeps its landmarks.

The web app manifest isn't linked or routed yet. NOTIFY-01's push story turns that on (`docs/design/notifications.md`, Push); this epic only gives the manifest its icons and colours, so the push story finds them ready.

## Elsewhere

- **`docs/design/app-shell.md`:** the sidebar's first item, and the `focused` layout's header, use `LogoComponent`.
- **`docs/design/app-shell/` and `docs/design/invitations/`:** the frames for the `focused` pages are redrawn with the new mark, centred where the person is signed out.
- **`CLAUDE.md`:** App Shell gains "Read `docs/design/brand.md` before touching the logo, favicon or app icons."
- **Canvas mockups** still draw the sun. They change as each page is redrawn; the story's screenshots show the new mark.

## States the story checks

- Light and dark, desktop and phone: the sidebar, the sign-in page
- Signed out (sign in, create an account, forgot password): the mark centred above the heading, and no logo in the corner
- Signed in on a `focused` page (the household chooser): the logo at the top left, and none above the heading
- The browser tab icon: SVG, and the PNG fallback
- The manifest's icons, sizes and colours
