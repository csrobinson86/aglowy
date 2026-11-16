# Notes

Each person's own notes to come back to: a title, a body with scripture links, a color, a collection and tags. It looks and works like Personal study (`docs/design/personal-study.md`). Stories live under the **NOTES-01** epic, which runs after TAGS-01 and PSTUDY-01's first story (#199, which adds `Collection`).

Frames in `docs/design/notes/` (README there). Mockups are in the "Notes" row on the design canvas.

## Decisions (Casey, 16 Nov)

- **A note has a title and a body**, with scripture links in the body (`docs/design/scripture-links.md`), tags (`docs/design/tags.md`) and one collection.
- **Color coding, like JW Library.** Each note can be no color, yellow, green, blue, purple, pink or orange. Only notes have colors.
- **Collections:** a base set shared with Personal study, plus collections that belong only to Notes (`Collection` in `docs/design/personal-study.md`).
- **In the first version:**
  - pin notes so they stay at the top
  - save a Personal study answer as a new note
  - show pinned notes on Home
- **Private**, like everything in Mine. Nobody else sees a person's notes; there's no sharing.

## Models

### `PersonalNote`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | Personal; follows the person |
| `collection_id` | uuid | FK → collections, nullable, `on_delete: :nullify` | Must be `Collection.for_notes` (validation) |
| `title` | string | not null, 1 to 120 characters | |
| `color` | string | not null, default `none`, check in (`none`, `yellow`, `green`, `blue`, `purple`, `pink`, `orange`) | |

- `has_rich_text :body, encrypted: true`, with `ScriptureLinkable`, so typed references link on save and the Scripture button works in the editor
- `include Taggable` (`docs/design/tags.md`; NOTES-01 adds `PersonalNote` to the tagging check)
- `has_one :pin`
- Scopes:
  - `pinned` and `unpinned`
  - `recent_first` by `updated_at`
  - `colored(color)`
  - `matching(text)` on title, collection name and tag name. The body is encrypted, so search can't read it, and the box says "Search titles, collections and tags"
- `scripture_references`: the references in the body, in order and without duplicates, for "Scriptures in this note"

### `PersonalNote::Pin`

State as a record: `personal_note_id` (FK, unique, `on_delete: :cascade`) and `created_at`. Pinned notes sort by when they were pinned, newest first.

## Colors

Colors come from Primer's display color primitives, so they follow light and dark mode. Sass lives in `components/_note_card.scss`, with a modifier per color:

| Color | Card background | Border | Left bar and swatch |
| --- | --- | --- | --- |
| none | `--bgColor-default` | `--borderColor-default` | `--borderColor-default` |
| yellow | `--display-yellow-bgColor-muted` | `--display-yellow-borderColor-muted` | `--display-yellow-borderColor-emphasis` |
| green, blue, purple, pink, orange | the same three primitives with that color's name | | |

The first story checks each primitive exists in the pinned `@primer/primitives` and records any substitute here.

- **Color is never the only signal.** Each card has a visually hidden "Yellow note" (or the color's name). Each swatch is a labelled radio ("Yellow"), and the picker shows the chosen color's name beside it.
- **The color picker** (frame `note.png`) is a radio group drawn as swatches: real `<input type="radio">` elements inside a Primer form, with a `<fieldset>` and the legend "Color". It's the fifth approved forms exception in `CLAUDE.md`.
- **The color filter** on the list is a row of toggle buttons with `aria-pressed`, labelled "Any color" and "Only yellow notes", and so on. It sets `?color=`.

## Pages and routes

Under `/:household_id` for the household layout. Always found through `Current.user.personal_notes`, so another person's note is a 404.

| What | Route | Frame |
| --- | --- | --- |
| Notes | `GET /:household_id/notes` (`PersonalNotesController#index`; `?collection=`, `?tag=`, `?color=`, `?q=`) | `notes.png` |
| New note | `GET /:household_id/notes/new`, `POST /:household_id/notes` | |
| A note | `GET /:household_id/notes/:id`, which opens straight into editing, as drawn | `note.png` |
| Save | `PATCH /:household_id/notes/:id` | |
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

- **Header:** the breadcrumb (Notes / the collection) and a "Pinned" toggle button.
- **The note card**, drawn in the note's color, holds:
  - the title field (labelled "Title", drawn large)
  - the color picker
  - the collection select ("None" plus `for_notes`)
  - the tag editor (`TagEditorComponent`)
  - the Lexxy body editor with the Scripture button
  - "Save note" and "Saved <time>"
- **Side panel:** "Scriptures in this note" (each a scripture link, with "Each opens on jw.org, or in JW Library if it's installed."), and Details (created, edited, Delete note).

### Pinned notes on Home

Home's Mine column (frame `home-pinned-notes.png`) gets "Pinned notes" above Recent meeting notes. It shows up to 5 notes, most recently pinned first, each with a color dot and its title, and "All notes" beneath. The section is hidden when the person has no pinned notes.

### Save an AI answer as a note

On a Personal study answer, next to "Save to notes", there's "Save as a note" (frame `docs/design/personal-study/personal-study.png`):
- `POST /:household_id/personal_studies/:id/questions/:question_id/personal_note` (`resource :personal_note, only: :create`) calls `question.save_as_note`
- the new note's title is the question, up to 120 characters
- its body is the same partial as "Save to notes": the escaped paragraphs with references as plain text, which link on save, then "Pages:" and the source links
- it takes the study's collection when that collection is shared with Notes, and the study's tags
- its color is none
- the person is taken to the new note
- only `answered` questions can be saved (422 otherwise)

## Traps

- **The body is encrypted.** Search and previews must decrypt in Ruby. Never search the body in SQL. Build the card preview from `body.to_plain_text`, truncated, and escaped like any text.
- **A collection's `used_in` decides where it can go.** Validate that a note's collection is `for_notes`, and a study's is `for_studies`.
- **Color modifiers come from the allowed list,** never interpolated straight from params into a class name.
- **Tags stay private** (`tags_for(Current.user)`). Notes are never shared, so there's no shared view to leak them, but use it anyway.
- **"Save as a note" copies, it doesn't link.** The note stands on its own if the study is deleted.

## States each story checks

- Owner, another member (404), a non-member (404)
- No notes; notes in every color; pinned and not; in a shared collection, a notes-only one and none; with tags
- Filters: collection, tag, color, search (title, collection, tag; not body)
- Home with and without pinned notes, with more than 5 pinned
- Desktop and phone; light and dark
