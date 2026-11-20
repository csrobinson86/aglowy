# Notes

Each person's own notes to come back to: a title, a body with scripture links, a color, a collection and tags. It looks and works like Personal study (`docs/design/personal-study.md`). Stories live under the **NOTES-01** epic, which runs after TAGS-01 and PSTUDY-01's first story (#199, which adds `Collection`).

Frames in `docs/design/notes/` (README there). Mockups are in the "Notes" row on the design canvas.

> Notes has three tabs: Notes, Meeting notes and Bookmarks (see Notes, Meeting notes and Bookmarks below). Since BOOKMARKS-01, "Scriptures in this note" also has a bookmark button on each scripture (`docs/design/bookmarks.md`).

## Decisions (Casey, 16 Nov)

- **A note has a title and a body**, with scripture links in the body (`docs/design/scripture-links.md`), tags (`docs/design/tags.md`) and one collection.
- **Color coding, like JW Library.** Each note can be no color, yellow, orange, red, pink, purple, blue, green, brown or gray (Casey, 17 Nov). Only notes have colors.
- **Collections:** a base set shared with Personal study, plus collections that belong only to Notes (`Collection` in `docs/design/personal-study.md`).
- **In the first version:**
  - pin notes so they stay at the top
  - a Personal study's note: "Save to note" on an answer adds it to the study's one note (Casey, 19 Nov; `docs/design/personal-study.md`, Save to note)
- **A note opens read-only (Casey, 19 Nov).** Clicking a note shows it; Edit opens the form with the Lexxy editor.
  - show pinned notes on Home
- **Private**, like everything in Mine. Nobody else sees a person's notes; there's no sharing.

## Notes, Meeting notes and Bookmarks

Meeting notes and bookmarks live in Notes, as tabs, so Mine stays short (decided by Casey, 16 Nov). Frames `notes-three-tabs.png`, `notes-meeting-notes.png`, `notes-meeting-notes-shared.png`, `notes-meeting-notes-dark.png` and `phone-notes-meeting-notes.png`, in the "Meeting notes as a tab in Notes" row on the design canvas.

- **The sidebar's Mine group** is Today's meeting, Personal study, Notes and My goals. "Meeting notes" goes away. "Notes" is selected on every page in this section: the three tabs, a note, a meeting note (with its steps and summary), and the shared list.
- **One header for all three tabs:** the `h1` "Notes" in a Primer `Subhead`, a line that fits the tab, and the tab's action:

  | Tab | Route | Line under the title | Action |
  | --- | --- | --- | --- |
  | Notes | `/:household_id/notes` | Your own notes to come back to. Only you can see them. | New note |
  | Meeting notes | `/:household_id/meeting_notes`, and `/:household_id/shared_meeting_notes` | Your meeting notes are private to you. Share one with your household when you want to. | My spiritual gems, only once that page exists (it's under Later in `docs/design/meeting-notes.md`); none until then |
  | Bookmarks | `/:household_id/bookmarks` (BOOKMARKS-01) | Pages and scriptures you saved to come back to. Only you can see them. | none |

- **`NotesTabsComponent.new(selected:)`** renders the tabs: a Primer `UnderlineNav` labelled "Notes, meeting notes and bookmarks", each tab a link with its icon (`pencil`, `note`, `bookmark`) and a `Counter`:
  - Notes counts the person's notes, Meeting notes their own meeting notes, Bookmarks their bookmarks
  - the current tab is `aria-current="page"`; the shared list selects Meeting notes
  - Bookmarks appears only once its page exists (#226 adds it)
  - below `md` the tabs fill the width and the counters are hidden
- **URLs don't change.** Meeting notes keep `/meeting_notes` and `/shared_meeting_notes`; only where they're reached from changes.

### The Meeting notes tab

Frame `notes-meeting-notes.png`. The same two columns as the Notes tab (`Primer::Alpha::Layout`, the side column folding behind a "Meetings and tags" `Details` on a phone):
- **Side column:**
  - **Meetings:** "All meetings", "Life and Ministry" and "Weekend meeting", each with its dot and count, setting `?kind=` (`MeetingNote.kinds`; an unknown kind is ignored). Each count is of the list showing: the person's own notes on their list, the household's shared notes on the shared list (decided in #239, so a count always matches what its filter shows)
  - **My tags:** the person's tags that are on a meeting note, with counts, setting `?tag=` (as today). Hidden on the shared list, where tags belong to their authors
- **Main column:**
  - "This week" with its two cards, as today, with a left bar in the meeting's color. Hidden while a filter is set, as today
  - "Earlier", with a Primer `SegmentedControl` labelled "Show": "Mine" and "Shared in <household>" with its count. They're links to `/meeting_notes` and `/shared_meeting_notes`, keeping `?kind=`. If the pinned `SegmentedControl` can't render links, use two `Button`s with `aria-current`, and record it here. The pinned 0.53.5 renders links (an item with `href` gets `aria-current` and no select action), so there's no fallback. While a filter hides This week, the heading reads "All weeks", since the list then holds this week's notes too
  - the list as today: dot, meeting, week, summary, tags (`tags_for(Current.user)`), "Shared", and Newer / Older notes
- The old "My notes" / "Shared in" `UnderlineNav` (`meeting_notes/_tabs`) goes away; a second row of tabs under the first is what the switch replaces.
- No search box: meeting notes are encrypted, and the meeting and tag filters cover finding one.

### A meeting note

Its breadcrumb starts "Notes / Meeting notes", linking to the Notes tab and the Meeting notes tab. Home's "All meeting notes" and Today's meeting's links still go to `/meeting_notes`, now the Meeting notes tab.

## Models

### `PersonalNote`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | Personal; follows the person |
| `collection_id` | uuid | FK → collections, nullable, `on_delete: :nullify` | Must be `Collection.for_notes` and owned by the note's `user` (validation). Looked up through `Current.user.collections`, so another person's id is a 404 |
| `title` | string | not null, 1 to 120 characters | |
| `color` | string | not null, default `none`, check in (`none`, `yellow`, `orange`, `red`, `pink`, `purple`, `blue`, `green`, `brown`, `gray`), the order the picker and the filter show | |
| `personal_study_id` | uuid | FK → personal_studies, nullable, `on_delete: :nullify`, unique where not null | The study this is the note of (`docs/design/personal-study.md`, Save to note). Must belong to the note's `user` (validation) |

- `has_rich_text :body, encrypted: true`, with `ScriptureLinkable`, so typed references link on save and the Scripture button works in the editor
- `include Taggable` (`docs/design/tags.md`; NOTES-01 adds `PersonalNote` to the tagging check)
- `has_one :pin`
- `belongs_to :personal_study, optional: true`
- Scopes:
  - `pinned` and `unpinned`
  - `recent_first` by `updated_at`
  - `colored(color)`
  - `matching(text)` on title, collection name and tag name. The body is encrypted, so search can't read it, and the box says "Search titles, collections and tags"
- `scripture_references`: the references in the body, in order and without duplicates, for "Scriptures in this note"

### `PersonalNote::Pin`

State as a record: `personal_note_id` (FK, unique, `on_delete: :cascade`) and `created_at`. Pinned notes sort by when they were pinned, newest first.

## Colors

Casey's nine colors (17 Nov, #313), an exception to Primer primitives only (`CLAUDE.md`, CSS & Design System). In this order, after **None** (no color, the default):

| Name | Card background |
| --- | --- |
| Yellow | `rgba(229, 223, 6, 0.3)` |
| Orange | `rgba(255, 185, 87, 0.3)` |
| Red | `rgba(255, 118, 118, 0.3)` |
| Pink | `rgba(248, 137, 216, 0.3)` |
| Purple | `rgba(190, 165, 255, 0.3)` |
| Blue | `rgba(124, 192, 252, 0.3)` |
| Green | `rgba(140, 255, 129, 0.3)` |
| Brown | `rgba(221, 170, 123, 0.3)` |
| Gray | `rgba(200, 200, 200, 0.3)` |

- **One place for the values:** `components/_note_colors.scss` defines `--note-color-<name>` (the background above) and `--note-color-<name>-strong` (the same color at alpha 1) on `:root`, and the `$note-colors` list every `@each` draws from. They're the same in light and dark mode: the 0.3 background sits over the theme's own.
- **Where they're drawn:** the card (`components/_note_card.scss`: background `--note-color-<name>`, border and left bar `-strong`), Home's dots, the picker's swatches and the filter's buttons (all `-strong`). None keeps `--bgColor-default` and `--borderColor-default`.
- **Muted text on a colored card** is drawn in `--fgColor-default`: in dark mode the colors are lighter than the theme's background, and Primer's muted text on them falls below 4.5:1.
- **So is accent text** (links, accent tag labels, scripture links), on every page that draws a colored card: the accent blue falls below 4.5:1 on orange and brown in light mode, and on the colors in dark mode (axe, #356, 19 Nov). Links keep their underline, and labels their accent border. The read view's frame shows them blue.
- **Avatars keep Primer's colors** (`Avatar::Palette`); their labelled swatches' rules outrank the note swatches'.

- **Color is never the only signal.** Each card has a visually hidden "Yellow note" (or the color's name). Each swatch is a labelled radio ("Yellow"), and the picker shows the chosen color's name beside it.
- **The color picker** (frame `note.png`) is a radio group drawn as swatches: real `<input type="radio">` elements inside a Primer form, with a `<fieldset>` and the legend "Color". It's the fifth approved forms exception in `CLAUDE.md`.
- **The note recolors as you choose.** Choosing a swatch on New note or a note's page swaps the card's color modifier at once; nothing is saved until "Save note", and leaving without saving keeps the saved color. New note draws its form in the same note card as a note's page.
- **The color filter** on the list is a row of toggle buttons with `aria-pressed`, labelled "Any color" and "Only yellow notes", and so on. It sets `?color=`.

## Pages and routes

Under `/:household_id` for the household layout. Always found through `Current.user.personal_notes`, so another person's note is a 404.

| What | Route | Frame |
| --- | --- | --- |
| Notes | `GET /:household_id/notes` (`PersonalNotesController#index`; `?collection=`, `?tag=`, `?color=`, `?q=`) | `notes.png` |
| New note | `GET /:household_id/notes/new`, `POST /:household_id/notes` | |
| A note | `GET /:household_id/notes/:id`: the read view | `note-read.png`, `note-read-from-study.png` |
| Edit a note | `GET /:household_id/notes/:id/edit`: the form | `note-editing.png` (`note.png` before 19 Nov) |
| Save | `PATCH /:household_id/notes/:id`, then back to the read view | |
| Delete | `DELETE /:household_id/notes/:id`, after a Primer dialog | |
| Pin and unpin | `resource :pin, only: %i[ create destroy ]` under the note (`PersonalNotes::PinsController`) | |
| Collections | `resources :collections` (shared; `docs/design/personal-study.md`) | `notes-new-collection.png` |
| On a phone | the list as stacked cards, and a collection picker behind "All notes ▾" | `phone-notes.png` |

### The list

- **Left column:**
  - Collections (`for_notes`), with the shared icon on shared ones and "Also used in Personal study" under the list, plus "+ New collection"
  - then My tags
- **Main column:**
  - search and the color filter
  - "Pinned", then "All notes", as a grid of cards
  - each card: the color, the title linking to the note, a three-line preview of the body as plain text, tags, and "Collection · N scriptures · date"
  - pinned cards carry an Unpin button (`aria-pressed="true"`)
- **Empty state:** "No notes yet. Write one to come back to." with "New note".

### A note

- **Header:** the breadcrumb (Notes / the collection), Edit (on the read view) and the "Pinned" toggle.
- **The read view** (frames `note-read.png`, `note-read-from-study.png`): the note card, drawn in the note's color, holds the title as the page's `h1`; a line with the color's name beside its dot, the collection as a link and the tags as links; for a study's note, "From your study" with the study's title linking to it (gone once the study is deleted); then the body as saved, with working scripture links. Nothing on it is a form field.
- **Edit** (frame `note-editing.png`) opens the form on its own page. **The note card**, drawn in the note's color, holds:
  - the title field (labelled "Title", drawn large)
  - the color picker
  - the collection select ("None" plus `for_notes`)
  - the tag editor (`TagEditorComponent`)
  - the Lexxy body editor with the Scripture button
  - "Save note", Cancel (back to the read view without saving) and "Saved <time>"
- **New note** still opens straight into the form, and saving it goes to its read view.
- **Tags on a new note (Casey, 20 Nov).** New note has the tag editor in the same place as Edit, under the form in the note card, so tags can be added before the first save. Until the note is saved, the editor only changes the page: adding a tag shows its Label with its remove button, and removing one takes it away, but nothing is sent. "Save note" sends the tags with the note as `personal_note[tag_names]` (space-separated; tag names have no spaces), copied in as the form is sent, as Edit already does for "What you wrote". `create` saves the note and adds each tag with `tag_with` in one transaction. If any tag is refused (a name that normalizes to nothing, more than 10 on the note, the person's 200-tag limit), nothing is saved and the form shows again with the error and the tags as they were typed. `docs/design/tags.md`, The tag editor, on a note that isn't saved yet.
- **The version check.** The edit form carries `personal_note[base]`, a hidden field holding the note's `updated_at` (microseconds, ISO 8601) when the form was rendered. `PersonalNote#revise(attributes, base:)` takes the note's row lock, compares `base` with `updated_at`, and saves only when they match. Every change to the body moves `updated_at`: a save from either form, and an answer appended by "Save to note" (`docs/design/personal-study.md`). So does a change to the title, color or collection. Adding or removing a tag doesn't move `updated_at`: the tag editor saves each tag at once (`docs/design/tags.md`, The tag editor), so a window's own tag change never spoils its `base`, and tags aren't part of the check (Casey, 19 Nov, option B). Both note forms use it, this one and the study page's (`PersonalStudies::NoteForm`).
  - **A stale save is refused, not merged.** Nothing is written, and the form renders again with status 409: every field holds the note as it is now, with the new `base`, under a Primer `Banner` (warning): "This note changed after you started editing, so your changes weren't saved. It's shown as it is now. What you wrote is below." Beneath the form, "What you wrote" shows every field submitted, read-only and escaped: the title, the color's name beside its dot, the collection, the tag names the form sent (the ones its editor showed when "Save note" was pressed; `revise` never writes tags, so a tag added in a window whose save is refused is still saved, and shows on the note as it is now), and the body rendered from the submitted Action Text (sanitized, as the read view renders a note), so its headings, lists and links keep their formatting when selected and pasted into the editor. A Primer `ClipboardCopyButton`, "Copy text", copies the body as plain text. The pinned 0.53.5 draws it as a copy icon only, so "Copy text" is its label; it's left out when the body is empty. The person picks what to keep, sets it in the form and saves again.
  - The offline replay check (`offline_base`, `docs/design/offline.md`) is separate and unchanged. Both hold the same `updated_at`.
- **Side panel**, on both views: "Scriptures in this note" (each a scripture link, with "Each opens on jw.org, or in JW Library if it's installed."), and Details (created, edited, Delete note).

### Pinned notes on Home

Home's Mine column (frame `home-pinned-notes.png`) gets "Pinned notes" above Recent meeting notes. It shows up to 5 notes, most recently pinned first, each with a color dot and its title, and "All notes" beneath. The section is hidden when the person has no pinned notes.

### A Personal study's note

A study has one note, made by its first "Save to note" or by "Start a note" on the study page (`docs/design/personal-study.md`, Save to note). It's an ordinary note in Notes, with `personal_study_id` set: it shows in the list like any other, and its read view says which study it's from. "Save as a note", which made a new note for each answer, is gone (Casey, 19 Nov).

## Traps

- **The body is encrypted.** Search and previews must decrypt in Ruby. Never search the body in SQL. Build the card preview from `body.to_plain_text`, truncated, and escaped like any text.
- **A collection's `used_in` decides where it can go.** Validate that a note's collection is `for_notes`, and a study's is `for_studies`.
- **Color modifiers come from the allowed list,** never interpolated straight from params into a class name.
- **Tags stay private** (`tags_for(Current.user)`). Notes are never shared, so there's no shared view to leak them, but use it anyway.
- **A study's note outlives the study.** `personal_study_id` is nullified when the study is deleted, and the read view drops "From your study".
- **Never save a whole body over a newer one.** Every save from a note form goes through `revise` with its `base`, under the row lock, so a form opened before "Save to note" appended an answer can't remove it.
- **The read view is still escaped.** The body is Action Text, rendered as saved; the title, collection and tags are escaped like any text.

## States each story checks

- Owner, another member (404), a non-member (404)
- Editing: saved; Cancel; a stale save refused (changed in another tab, or an answer saved to a study's note meanwhile)
- No notes; notes in every color; pinned and not; in a shared collection, a notes-only one and none; with tags
- Filters: collection, tag, color, search (title, collection, tag; not body)
- Home with and without pinned notes, with more than 5 pinned
- Desktop and phone; light and dark
