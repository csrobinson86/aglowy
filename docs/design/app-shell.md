# App shell

How every Aglowy page is framed: the sidebar, the main area, the phone menu,
and the page patterns inside them. Read this before touching a layout,
navigation, or a page's header or empty state. Stories for this live under
the **UI-01** epic.

The approved mockup has twelve frames: desktop light and dark, the switcher
open, a child's view, an empty household, phone home, menu and dark, and the
signed-out pages (sign in, create an account, sign in dark, phone sign in).
A thirteenth frame shows account settings with the Dark appearance chosen
(see Theming and appearance).
Exported frames go in `docs/design/app-shell/` (one PNG per frame, named as
below). When a story's screenshot and a frame disagree, the frame wins unless
this document says otherwise.

| Frame | File |
| --- | --- |
| Desktop · head · light | `desktop-light.png` |
| Desktop · dark | `desktop-dark.png` |
| Household switcher open | `desktop-switcher.png` |
| Child's view | `desktop-child.png` |
| New household (empty) | `desktop-empty.png` |
| Phone · home | `phone-home.png` |
| Phone · menu open | `phone-menu.png` |
| Phone · dark | `phone-dark.png` |
| Sign in (root page) | `sign-in.png` |
| Create an account | `sign-up.png` |
| Sign in · dark | `sign-in-dark.png` |
| Phone · sign in | `phone-sign-in.png` |
| Account settings · dark appearance chosen | `account-settings-dark.png` |

## Two layouts

| Layout | Used by | Shape |
| --- | --- | --- |
| `household` | Every controller that includes `HouseholdScoped`, except the meeting helper's pages for a child | The app shell: sidebar + main |
| `meeting_helper` | The meeting helper's pages for a child with the helper on (`docs/design/meeting-helper.md`) | Full screen, always dark, no sidebar |
| `focused` | Pages outside a household: sign in, password reset, confirmation, sign up, the household chooser, new household | The Aglowy mark (`LogoComponent`, `docs/design/brand.md`), then one centred column. Signed out, the mark is centred above the column; signed in, it's at the top left. No sidebar, because there is no household to navigate |

Every layout keeps `lang` on `<html>` and the `<body>` theming attributes
described next.

## Theming and appearance

Every layout sets the theme on `<body>`:
`data-color-mode="<%= color_mode %>" data-light-theme="light" data-dark-theme="dark"`.
Primer's components and primitives follow `data-color-mode`, so nothing else
changes when it does.

- **The mode is the signed-in person's choice.** (Since SETTINGS-01 the
  Appearance section is its own page in Settings, `docs/design/settings.md`,
  and saves to `PATCH /:household_id/settings/appearance`.) Account settings has an
  Appearance section, between Profile and Signing in (frames
  `docs/design/invitations/account-settings.png`, Match my device, and
  `account-settings-dark.png`, Dark). It holds a radio group "Theme" and a
  "Save appearance" button:

  | Choice | Value | Caption |
  | --- | --- | --- |
  | Match my device (the default) | `auto` | Light or dark, following your phone or computer's setting. |
  | Light | `light` | Always light, whatever your device is set to. |
  | Dark | `dark` | Always dark. Easier on the eyes in the evening and at meetings. |

- **It's stored on the person.** `users.appearance`: string, not null,
  default `"auto"`, with a check constraint allowing only `auto`, `light` and
  `dark`. It belongs to `User`, like the time zone, so it follows the person
  into every household and onto every device they sign in on. It isn't a
  household setting, and a head can't set it for anyone else.
- **One helper reads it.** `ApplicationHelper#color_mode` returns
  `Current.user&.appearance || "auto"`. The `household`, `focused` and
  `application` layouts use it. Signed out there's no person, so sign in, sign
  up and the password pages stay `auto`.
- **Two layouts don't use it.** `meeting_helper` stays `dark` whatever the
  child chose (`docs/design/meeting-helper.md`). `design_system`, a
  development page, stays `auto`.
- **Saving.** From a household, `PATCH /:household_id/settings/appearance`
  (`Settings::AppearancesController#update`, `docs/design/settings.md`). It
  authorizes `@user` with `UserPolicy#update?`, saves with
  `@user.update(appearance:)` and redirects to Settings → Appearance with the
  notice "Your appearance is saved." There's no `return_to`. A person with no
  household saves on `/account` instead: `PATCH /account/appearance`
  (`Accounts::AppearancesController#update`), which returns to `/account`.
  Both use the same form, `Settings::AppearanceForm` (formerly
  `Accounts::AppearanceForm`), a Primer form class with `radio_button_group`.
  The redirect renders a new `<body>`, so the page changes theme as soon as
  it's saved. There's no live preview and no JavaScript.

### Traps

- **Never style by `@media (prefers-color-scheme)`** or read
  `matchMedia("(prefers-color-scheme: dark)")` in JavaScript. They report the
  device, not the person's choice, so someone who chose Light on a dark phone
  would get dark pieces on a light page. Use Primer primitives, which follow
  `data-color-mode` (this is why `components/_lexxy.scss` maps Lexxy's colours
  to primitives).
- **The database is the only store.** No cookie or `localStorage` copy, so the
  choice is the same on every device and signed-out pages stay `auto`.
- **Emails don't use it.** They're read in a mail app with its own theme.
- **Impersonation** shows the impersonated person's choice. That's expected:
  it's their account.

## The root page and signing in

- `/` is the sign-in page for visitors. A signed-in person who visits `/` goes where signing in would send them: their household, the chooser, or new household.
- **Sign in** (frame `sign-in.png`):
  - The Aglowy mark, 48 px, centred above the heading (`docs/design/brand.md`). There's no logo in the top-left corner.
  - The heading "Sign in to Aglowy", with "To be aglow with the spirit" underneath.
  - One box holding Email, Password (with "Forgot password?" beside its label), "Remember me" and a full-width primary "Sign in" button.
  - Under the box: "New to Aglowy? Create an account", then a small "Didn't get the confirmation email?" link.
- **Create an account** (frame `sign-up.png`):
  - The same centred mark, then the heading "Create your account", with a line saying you'll be the head of your household.
  - Your name, Email and Password; a divider; then Household name (with a hint) and Time zone.
  - "Create account", with a note that a confirmation email comes first.
  - Under the box: "Already have an account? Sign in".
- Both are Primer form classes (`CLAUDE.md`, Forms) in the `focused` layout. The sign-in column is narrower than the sign-up column.

## Anatomy of the shell

```
┌───────────────────────┬──────────────────────────────────────────────┐
│ ☀ Aglowy              │  Flash (if any)                              │
│ ┌───────────────────┐ │                                              │
│ │ R  Rivera househ… ▾│ │  Home                       [Primary action] │
│ │    Head            │ │  Rivera household                            │
│ └───────────────────┘ │  ─────────────────────────────────────────── │
│ Household             │                                              │
│ ▌⌂ Home               │  Page content                                │
│   ▤ Family studies    │                                              │
│   ☺ Members           │                                              │
│   ◎ Family goals      │                                              │
│ Mine                  │                                              │
│   ✎ Notes             │                                              │
│   ⚑ My goals          │                                              │
│                       │                                              │
│ ───────────────────── │                                              │
│   ⚙ Settings          │                                              │
│ (M) Maria R. [Sign out]│                                             │
└───────────────────────┴──────────────────────────────────────────────┘
```

**Sidebar, top to bottom**

1. **Aglowy mark:** `LogoComponent`, the Two flames mark then "Aglowy" (`docs/design/brand.md`). Links to the household home.
2. **Household switcher:** the current household's name, with the person's role in it (Head, Adult, Child) underneath. With two or more active households it opens a menu of them, the current one checked, each with its role. With one, it isn't a menu: the same two lines as plain text, with no chevron and nothing to press. "New household" isn't in the switcher; it's in Settings → My households (`docs/design/settings.md`; Casey, 21 Nov).
3. **Household group:** Home, Calendar (`docs/design/calendar.md`, once CAL-01 builds it), Family studies, Members, Family goals.
4. **Mine group:** Daily brief (`docs/design/daily-brief.md`, heads and adults), Today's meeting, Personal study (`docs/design/personal-study.md`), Notes (`docs/design/notes.md`, whose tabs hold notes, meeting notes and bookmarks), Meeting parts (`docs/design/meeting-parts.md`), My goals. These follow the person between households (`docs/design/users.md`), which is why they're grouped apart.
5. **Footer:** Notifications with its unread counter, once NOTIFY-01 adds it (`docs/design/notifications.md`, The sidebar), then Settings, for everyone (`docs/design/settings.md`; it replaced Household settings and the link on the person's name in SETTINGS-01), then the person's initial and name with a Sign out button.

**Main**

1. Flash messages, then the impersonation banner when staff are impersonating.
2. A page header (title, optional description, optional actions), with breadcrumbs above the title on nested pages (for example Members › Add a member).
3. The page content, capped at Primer's `xl` main width (`with_main(width: :xl)`), so it fills the main area on a laptop and stops growing on wide screens.

## Primer components (verified against `primer_view_components` 0.53.5)

| Part | Component and arguments |
| --- | --- |
| Shell | `Primer::Alpha::Layout` with `stacking_breakpoint: :md`. `with_sidebar(width: :default, col_placement: :start, row_placement: :none)` hides the sidebar below `md`, where the phone menu takes over. `with_main(tag: :main, width: :xl)` |
| Navigation | `Primer::Beta::NavList` with `selected_item_id:`. It renders its own `<nav>`; give it `aria: { label: "Main" }` (it raises without a heading or label). Two `with_group` blocks, each `with_heading(title: "Household")` / `"Mine"`. Items: `with_item(label:, href:, selected_by_ids: :dashboards)` and `with_leading_visual_icon(icon: :home)`. A selected item gets `aria-current="page"` from Primer |
| Switcher | With two or more households, `Primer::Alpha::ActionMenu` with `select_variant: :single`. Each household is `with_item(label:, href:, active: current)` with `with_description` for the role. With one, the name and role as text in the same two-line layout, no button |
| Phone menu button | `Primer::Beta::IconButton` with `icon: :"three-bars"` and `"aria-label": "Open menu"`, in a top bar shown only below `md` (`d-md-none`) |
| Phone menu | `Primer::Alpha::Dialog` with `position: :left`, `position_narrow: :left` and `title: "Menu"`. Its body renders the same sidebar content as the desktop sidebar |
| Page header | `Primer::Beta::Subhead`. Pass `with_heading(tag: :h1)`: the default tag is a `div` |
| Breadcrumbs | `Primer::Beta::Breadcrumbs` (`with_item(href:)`) |
| Empty states | `Primer::Beta::Blankslate` with `with_visual_icon`, `with_heading(tag: :h2)`, `with_description` and `with_primary_action(href:)` |
| Messages | `Primer::Beta::Flash`: `scheme: :default` for notice, `:danger` for alert |
| Impersonation | `Primer::Alpha::Banner` with `scheme: :warning` |
| Icons | Octicons, all present in octicons 19.42.0: `home`, `book`, `people`, `goal`, `note`, `milestone`, `gear`, `sign-out`, `three-bars`, `sun`, `plus`, `calendar`, `link`, `file`, `check`, `chevron-down`, `x` |

Wrap the shell in one ViewComponent, `AppShellComponent`, with the sidebar
contents in `AppShell::SidebarComponent` so the desktop sidebar and the phone
dialog render the same thing. Custom Sass is only for what Primer lacks (for
example the switcher button's two-line label), with BEM names and primitives
(`CLAUDE.md`, CSS & Design System).

## Navigation rules

- **An item appears only when its page exists.** At the end of UI-01 that is Home and Members. Family studies, Family goals, Meeting notes, My goals and Household settings each join the list in the story that builds their page.
- **Which item is selected:** each item's `selected_by_ids` is its controller's name (`:dashboards`, `:members`), and the shell passes `controller_name.to_sym` as `selected_item_id`. Nested pages (`members#new`) keep their section selected.
- **Hiding a link is not authorization.** Every role-gated item or button also has the matching policy check in its controller. Settings shows each person only the sections their role allows, and each section's controller still authorizes.

## Phone (below `md`, 768px)

- The sidebar is hidden. A 56px top bar holds three things (Casey, 21 Nov):
  - on the left, the menu button
  - beside it, left-aligned, the Aglowy mark alone (`LogoComponent` `size: :small`, `docs/design/brand.md`), linking to the household's Home. It sits right after the menu button, as a logo does beside a menu icon, rather than centred (Casey, 21 Nov)
  - on the right, the bell with its counter (`docs/design/notifications.md`, The sidebar)
- The household switcher isn't in the top bar. It's at the top of the menu, as in the desktop sidebar, since the menu is the same sidebar content.
- The menu button opens the left-side dialog with the full sidebar content.
- Touch targets are at least 44px. Primer's coarse-pointer sizes should provide this; the screenshots confirm it.
- Primary page actions go full width under the page title.

## States every UI story checks

A story names the ones that apply; its screenshots or ViewComponent previews show each one.

- **Role:** head, adult, child
- **Households:** one, several
- **Content:** empty (a brand-new household), typical, many items, long names (household and person names truncate with an ellipsis and never wrap the sidebar)
- **Viewport:** desktop (1440 × 1000) and phone (390 × 844)
- **Theme:** light and dark
- **Messages:** a flash present; staff impersonating

## Screenshots

System tests can save screenshots of a page at both viewports and in both themes (UI-01, "Screenshots of every page"). They go to `tmp/screenshots/ui/<page>-<viewport>-<theme>.png`. CI uploads them as a build artifact, and UI pull requests attach the desktop and phone light screenshots, plus dark when colours change.

## Home's New menu

Casey, 21 Nov: Home's header has one menu of quick actions instead of the "Schedule a study" button, so the things people start most often are a click away from Home.

- **The button:** a Primer `ActionMenu` whose show button is a primary `Button` with the `plus` leading icon, the label "New" and the `triangle-down` trailing action. It's a plus, not the "…" a study page uses: "…" means "more about this thing", and Home's menu starts new things. Its accessible name is "New".
- **The items, in this order,** each with the same icon as its sidebar item, and each shown only when that page's own policy allows it:

| Item | Icon | Goes to | Shown when |
| --- | --- | --- | --- |
| Family study | `book` | `new_household_family_study_path` | `policy(FamilyStudy).create?` (heads and adults) |
| Personal study | `search` | `new_household_personal_study_path` | everyone (`PersonalStudyPolicy#create?` for their own new study) |
| Note | `pencil` | `new_household_personal_note_path` | everyone |
| Family goal | `goal` | `new_household_goal_path` | `GoalPolicy#create?` for a family goal (heads and adults) |
| Member | `people` | `new_household_member_path`, after a divider | `policy(Membership).create?` (heads and adults) |

- The labels are nouns because the button already says "New": the menu reads "New › Family study".
- A child sees Personal study and Note. Nothing else changes for them: no item leads anywhere they couldn't already go.
- On a phone the button goes full width under the title, as primary page actions do (Phone, above), and the menu opens under it.
- Everything else on Home stays as it is, including the Welcome Blankslate's own actions.

## Decisions

| Decision | Choice |
| --- | --- |
| Personal content on the household home | Shown as drawn: a "Mine" column with my goals, pinned notes (NOTES-01, `docs/design/notes.md`, frame `docs/design/notes/home-pinned-notes.png`) and recent meeting notes, once those features exist (the meeting notes and goals epics). Until then Home has no Mine column |
| Who sees "New household" | Whoever `HouseholdPolicy#create?` allows (`User#can_start_household?`): someone with no seats may, and so may anyone with at least one seat that isn't a child seat. It counts every seat the person has had, including ones they've left, so only someone who has only ever been a child may not (decided 14 Nov, `docs/design/invitations.md`). Their role in the household in the URL doesn't decide it. It's a button in Settings → My households, not a switcher item (Casey, 21 Nov) |
| Household home before family studies exist | The Welcome empty state shows only when there is nothing at all to show: no upcoming session, no active family goal, and none of the person's own active goals, meeting notes or pinned notes (story #142; pinned notes added by NOTES-01). Otherwise Home shows its two columns, with "No family study scheduled." in Next family study when nothing is scheduled. Heads and adults see "Schedule a study" as the empty state's action and "Add a member" beside it. The page header holds the New menu instead of a "Schedule a study" button, on the Welcome state too (Home's New menu, above) |
| Phone navigation | A left-side `Primer::Alpha::Dialog` (0.53.5 supports `position: :left` and `position_narrow: :left`) |
| Icons in the mockup | Hand-drawn stand-ins; the build uses the Octicons listed above |
