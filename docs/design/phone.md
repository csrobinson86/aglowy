# Tidier phone pages

Casey, 21 Nov: on a phone, pages feel disorganized. Buttons wrap under titles, labels sit on lines of their own, and forms stay open. My goals is the worst case: a lot of information that is hard to take in. This doc sets one layout for every page below Primer's `md` breakpoint (768px). **Desktop doesn't change** unless a section below says so.

It builds on `docs/design/app-shell.md` (Phone, Home's New menu) and on each page's own design doc. Where they differ on a phone, this doc wins.

Frames are in `docs/design/phone/` (README there), from the "Tidier phone pages (proposal)" rows on the design canvas.

## Decisions (Casey, 21 Nov)

- **The "…" for an inner page's own actions sits at the right end of the back-link row**, as a plain icon with no background or border. The title gets the full width under it. A "…" beside the title felt cramped.
- **On a family goal, tapping a step opens a panel from the bottom** with everything about that step. The list itself has no pencils or buttons.
- **A top-level page keeps its "+ New" beside the title.** It doesn't take a full-width row of its own.
- **Every page with a long header is covered**, not only My goals and Members.
- **A note's Edit is inside its "…" menu,** like every other inner page's actions.

## The rules

1. **A top-level page** (one in the sidebar: Home, Calendar, Notes, Personal study, Family studies, Family goals, My goals, Members) **has a title row**: the `h1`, and at its right one primary button. That button is "+ New ▾" when the page starts more than one kind of thing (`docs/design/app-shell.md`, Home's New menu), or "+ New" when it starts one. It's 44px tall and as wide as its label, beside the title, never under it. On a phone, a single-action button's label shortens to "New": Family studies shows "+ New", not "+ Schedule a study".
2. **An inner page** (one with a back link: a goal, a note, a study, a session) **has a back row**: "‹ <parent>" on the left, and the page's "…" at the right end as a plain `IconButton` (`scheme: :invisible`, Octicon `kebab-horizontal`). Breadcrumbs are hidden on a phone; the back link goes to the last breadcrumb above this page. Under the back row: the `h1` at full width, then one meta line.
3. **One meta line of facts under the title**, small and muted ("Private · Milestone · Target Dec 31, 2026"). Labels like "Milestone" and "Private" become words in it. Page descriptions that only explain the page ("Goals the whole household works toward together.") are hidden on a phone. A description that says who can see the page stays, shortened: "Only you can see these." Home keeps its household name and date.
4. **Every action that isn't the page's main one goes in the "…" menu**: Edit, Share, Tags, Pin, Move, Complete, Archive, Delete. Destructive items come last, after a divider, in danger red, with "…" after the label because they ask first.
5. **Tags show as small read-only chips** under the meta line. They're changed from the "…" menu's "Tags…", which opens the tag editor in a Primer `Dialog`, as Personal study already does on a phone.
6. **A list row is one thing:** at most two lines (the name, then one muted line), and at most one control at its end. That's either "›" when the whole row opens something, or a plain "…" for the row's actions. No buttons, labels or pencils inside rows.
7. **Forms open when asked.** An add-row form is hidden behind a "+ Add <thing>" button at the bottom of its list, and Cancel hides it again.
8. **Touch targets are at least 44px**, as the app shell already requires.

## Pages

### A goal (frames `phone-goal.png`, `phone-goal-menu.png`, `phone-goal-add-step.png`, `phone-goal-dark.png`)

- **Back row:** "‹ My goals" or "‹ Family goals", and the goal's "…".
- **The "…" menu**, for those who can edit:
  - Edit goal
  - Share with household… (personal goals)
  - Tags… (personal goals)
  - divider, then Mark goal complete and Archive
  - divider, then Delete goal…

  A completed or archived goal's menu has Reopen or Restore instead of Mark goal complete and Archive.
- **Meta line:** a personal goal shows `lock` "Private" or "Shared with <household>", then "Milestone · Target <date>". A family goal shows "Milestone · Target <date> · Set by <name>".
- **The why** (if any) follows as plain text. A personal goal's tags follow as chips.
- **Progress card:** "1 of 2 steps done" with the percentage on the right, the `ProgressBar`, and "Next: <step> · due <date>" when an undone step has a due date. A family goal adds one line with each person's avatar, name and count ("Maria 4 · Eli 4 · Sofia 3").
- **Steps:**
  - An `h2` "Steps", then a bordered list.
  - Each row has the tick box, the step's title (struck through when done), and one muted line: "Done Nov 18" or "Due Dec 18". On a family goal the line starts with who it's for ("Eli and Sofia · Eli done, waiting on Sofia").
  - Each row ends with "›", and tapping the row opens the step panel.
  - The tick box stays in the row, so ticking needs no panel. On a step for named people, the row's box is for the person viewing when they're one of them. Otherwise it opens the panel.
- **"+ Add step"** is the list's last row for those who can edit. It opens the add-step form in place (New step, For on a family goal, Due), with "Add step" and "Cancel".
- **The step panel** (frame `phone-family-goal-step.png`) is a Primer `Dialog` with `position_narrow: :bottom`:
  - the step's title as its heading, and "For <names> · Due <date>"
  - "Who's done it", with a tick box per assignee, for a step for named people
  - "Schedule as a family study" (family goals, heads and adults)
  - "Edit step" and "Remove step"

  A personal goal's panel has the title, due date, Edit step and Remove step. Edit step swaps the panel's body for the step's form.

### Members (frames `phone-members.png`, `phone-members-menu.png`)

This change is on **every screen size**, because Members starts two kinds of thing (`docs/design/app-shell.md`, Home's New menu):
- **The title row:** "+ New ▾" with "Invite by email" (`mail`) and "Add without a login" (`person-add`), each shown when its policy allows. It replaces the two buttons.

On a phone only:
- **Member rows:** the avatar, the name, then one muted line: the role and the email, or "signs in as <username>", or nothing more for a child without a login. The role becomes words; the `Label` stays on desktop.
- **A row's actions** go behind a plain "…" at its end: Give a login, New password link, Read <name>'s personal study, as each applies today. A row with none shows no "…".
- **"Invited, not joined yet"** rows show the email, then "<role> · invited by <name> · until <date>", and a "…" holding Resend (or Send again) and Cancel invitation….

### Notes (frames `phone-notes.png`, `phone-note.png`, `phone-note-menu.png`)

- **The list:**
  - The title row has "+ New ▾" with Note and Collection. Collection opens the existing "New collection" dialog, which leaves the "All notes ▾" menu on a phone.
  - "Only you can see these." sits under the title.
  - One row under it holds "All notes ▾" (the collection and tag picker, as today) and a search `IconButton` that opens the search field.
  - Each note is a row: its color dot, the title, a one-line preview and one muted line (collection · tags · date).
- **A note:**
  - The back row is "‹ Notes" (or the collection) with the note's "…": Edit note, Pin to Home or Unpin from Home, Move to collection…, then a divider and Delete note….
  - The Edit button and the Pinned toggle leave the header on a phone.
  - The note card, its scriptures and its details stay as they are.

### A personal study (frame `phone-personal-study.png`)

- **The header:**
  - The back row is "‹ <collection or Personal study>" with the study's "…" (today's phone menu: Create family study, Tags…, Rename…, Move to collection…, Delete study…).
  - The title follows, then the meta line "Started <date> · N questions · N pages linked".
  - The tabs stay.
- **Pages used:** each answer's pages fold into one row, "<N> pages used ›", that opens them in place (a Primer `Details`). "Save to note" stays under the answer.
- **The ask box** stays at the bottom of the screen while the conversation scrolls.
- **Personal study's list** works like Notes': "+ New ▾" with Study and Collection, and "Only you can see these." only when it's true.

### Family studies (frames `phone-family-studies.png`, `phone-family-study-session.png`)

- **The list:** the title row has "+ New", for heads and adults. Below it:
  - a "Next" card (the next session's topic, then its day, time and repeat)
  - "Coming up": one row per session, with the month and day on the left, the topic ("Topic not chosen yet" muted) and "<weekday> · <time>", and "›"
  - "Past studies" as a link
- **A session:**
  - The back row is "‹ Family studies" with the session's "…": Edit session, then a divider and Cancel this session… (or Restore this session).
  - The title follows, then "Tuesday, Nov 24 · 7:00–7:45 PM · Every Tuesday"; a cancelled session adds "Cancelled" in danger red.
  - The Notes heading has a plain "Edit" link at its right instead of a button.
  - Resources are rows.

### Calendar (frame `phone-calendar.png`)

- The title row has "+ New ▾", beside the title rather than full width (`docs/design/calendar.md`).
- One toolbar row: "Today", then "‹", the range ("Nov 16 – 22") centred, "›", and the "Show on the calendar" filter `IconButton`.
- The day list is unchanged.

### Home

Its "+ New ▾" sits beside the title, not full width (rule 1). Nothing else on Home changes.

## Building it

- **`BackRowComponent`** (`app/components/back_row_component.rb`): `href:` and `label:`, and a `renders_one :menu` slot for the page's `Primer::Alpha::ActionMenu`. It renders only below `md` (`d-md-none`), beside the page's breadcrumbs, which become `d-none d-md-block`. Each inner page passes its menu.
- **Desktop markup stays,** shown from `md` up. Where the phone needs other controls (a row's "…" instead of its buttons), both are rendered, with `d-md-none` and `d-none d-md-flex`. This is the pattern Calendar and Personal study use today. An `ActionMenu` hidden at one size has its own `menu_id`.
- **No new colors or sizes:** Primer components, utilities and primitives only.

## States every story checks

- Head, adult, child; a page with and without the "…" (a child's view of a family goal has no menu)
- Long titles and names (they wrap, never push the "…" or "+ New" off screen)
- Light and dark; phone (390 × 844) and desktop (desktop unchanged)
- `assert_accessible` with each menu and panel open; `capture_screens` phone, light and dark

## Changes to other docs

- `docs/design/app-shell.md`, Phone: "Primary page actions go full width under the page title" becomes "A page's primary action sits beside its title (`docs/design/phone.md`)". Home's New menu says the same.
- `docs/design/calendar.md`, On a phone: the New menu sits beside the title.
- `docs/design/goals.md`, `docs/design/invitations.md` (the Members page), `docs/design/notes.md`, `docs/design/personal-study.md` and `docs/design/family-studies.md` each point here for the phone.
- `CLAUDE.md`, App Shell and Page Patterns: "Read `docs/design/phone.md` before touching how a page looks on a phone."
