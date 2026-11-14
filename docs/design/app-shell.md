# App shell

How every Aglowy page is framed: the sidebar, the main area, the phone menu,
and the page patterns inside them. Read this before touching a layout,
navigation, or a page's header or empty state. Stories for this live under
the **UI-01** epic.

The approved mockup has eight frames: desktop light and dark, the switcher
open, a child's view, an empty household, and phone home, menu and dark.
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

## Two layouts

| Layout | Used by | Shape |
| --- | --- | --- |
| `household` | Every controller that includes `HouseholdScoped` | The app shell: sidebar + main |
| `focused` | Pages outside a household: sign in, password reset, confirmation, sign up, the household chooser, new household | One centred column with the Aglowy mark on top. No sidebar, because there is no household to navigate |

Both keep the `<body>` theming attributes from `CLAUDE.md`
(`data-color-mode="auto" data-light-theme="light" data-dark-theme="dark"`)
and `lang` on `<html>`.

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
│   ▢ Meeting notes     │                                              │
│   ⚑ My goals          │                                              │
│                       │                                              │
│ ───────────────────── │                                              │
│   ⚙ Household settings│                                              │
│ (M) Maria R. [Sign out]│                                             │
└───────────────────────┴──────────────────────────────────────────────┘
```

**Sidebar, top to bottom**

1. **Aglowy mark:** Octicon `sun` in the attention colour, then "Aglowy". Links to the household home.
2. **Household switcher:** the current household's name, with the person's role in it (Head, Adult, Child) underneath. Opens a menu of their active households, the current one checked, each with its role. Below a divider, "New household" appears when `HouseholdPolicy#create?` allows it.
3. **Household group:** Home, Family studies, Members, Family goals.
4. **Mine group:** Meeting notes, My goals. These follow the person between households (`docs/design/users.md`), which is why they're grouped apart.
5. **Footer:** Household settings (heads only), then the person's initial and name with a Sign out button.

**Main**

1. Flash messages, then the impersonation banner when staff are impersonating.
2. A page header (title, optional description, optional actions), with breadcrumbs above the title on nested pages (for example Members › Add a member).
3. The page content, capped at Primer's `xl` main width (`with_main(width: :xl)`), so it fills the main area on a laptop and stops growing on wide screens.

## Primer components (verified against `primer_view_components` 0.53.5)

| Part | Component and arguments |
| --- | --- |
| Shell | `Primer::Alpha::Layout` with `stacking_breakpoint: :md`. `with_sidebar(width: :default, col_placement: :start, row_placement: :none)` hides the sidebar below `md`, where the phone menu takes over. `with_main(tag: :main, width: :xl)` |
| Navigation | `Primer::Beta::NavList` with `selected_item_id:`. It renders its own `<nav>`; give it `aria: { label: "Main" }` (it raises without a heading or label). Two `with_group` blocks, each `with_heading(title: "Household")` / `"Mine"`. Items: `with_item(label:, href:, selected_by_ids: :dashboards)` and `with_leading_visual_icon(icon: :home)`. A selected item gets `aria-current="page"` from Primer |
| Switcher | `Primer::Alpha::ActionMenu` with `select_variant: :single`. Each household is `with_item(label:, href:, active: current)` with `with_description` for the role. "New household" goes after `with_divider` |
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
- **Hiding a link is not authorization.** Every role-gated item or button also has the matching policy check in its controller. The sidebar shows Household settings to heads only, and the settings controller still authorizes.

## Phone (below `md`, 768px)

- The sidebar is hidden. A 56px top bar holds the menu button, then the household switcher.
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

## Decisions

| Decision | Choice |
| --- | --- |
| Personal content on the household home | Shown as drawn: a "Mine" column with my goals and recent meeting notes, once those features exist (the meeting notes and goals epics). Until then Home has no Mine column |
| Who sees "New household" | Whoever `HouseholdPolicy#create?` allows. Whether children may create households is decided with child logins (the invitations and child logins epic); the menu follows the policy |
| Household home before family studies exist | Page header plus an empty state. A head sees "Add a member" as its action |
| Phone navigation | A left-side `Primer::Alpha::Dialog` (0.53.5 supports `position: :left` and `position_narrow: :left`) |
| Icons in the mockup | Hand-drawn stand-ins; the build uses the Octicons listed above |
