# Meeting notes

How each person keeps notes from the congregation meetings, and how they can share a note with their household. Read this before touching `MeetingNote`, its parts, gems or sharing. Stories live under the **NOTES-01** epic. Mockup frames are in `docs/design/meeting-notes/`.

This replaces the single-body `MeetingNote` sketched in `docs/design/users.md`: notes now follow the meeting's outline, part by part, so gems can be collected later.

## Principles

- **Personal content follows the person.** A note belongs to its author (`User`), never to a household, and stays theirs if they move households (vision, principles).
- **Private by default.** Nobody else sees a note until its author shares it. Sharing is per note and per household, and read-only for everyone else.
- **We link the program, we don't copy it.** People type part titles themselves. Each note links to that week's page on wol.jw.org. No workbook or Watchtower text is stored or fetched (vision, non-goals).
- **The outline is a shell, not a form to complete.** Every part is optional; empty parts are hidden when reading.

## What NOTES-01 builds, and what comes later

| In NOTES-01 | Later |
| --- | --- |
| Life and Ministry notes on the current outline | "My spiritual gems" page (frame `spiritual-gems-later.png`) |
| Weekend meeting notes (Public Talk, light Watchtower Study) | Autosave while typing |
| Spiritual Gems as scripture + insight entries | Search across notes |
| Meeting notes list with this week's two notes | Assemblies, conventions, the Memorial, the circuit overseer's visit |
| Share a note with one household, stop sharing | |
| A household's "Shared" tab, read-only view | |

## The outlines

Defined in code, not in the database, as `MeetingNote::Outline` (a PORO in `app/models/meeting_note/outline.rb`). Each note stores the `outline_version` it was created with, so a future format change gets a new version and old notes keep their shape.

**Version 1, Life and Ministry** (checked against the jw.org meeting instructions, S-38 8/26):

| Section (dot colour) | Part key | Fields | Repeats |
| --- | --- | --- | --- |
| Treasures From God's Word (grey) | `talk` | title, notes | no |
| | `spiritual_gems` | gem entries (scripture + insight) | gems repeat |
| | `bible_reading` | notes | no |
| Apply Yourself to the Field Ministry (gold) | `field_ministry` | notes for the whole section | no |
| Living as Christians (red) | `living_part` | title, notes | yes, starts with one |
| | `congregation_bible_study` | notes | no |

**Version 1, Weekend meeting:**

| Section | Part key | Fields | Repeats |
| --- | --- | --- | --- |
| Public Talk | `public_talk` | title, speaker, notes (large) | no |
| Watchtower Study | `watchtower_study` | article title, a point to remember | no |

The Watchtower section says: "Follow along and mark your answers in JW Library. Keep anything you want to remember here."

## Models

### `MeetingNote`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | The author; personal content |
| `kind` | string | not null, check in (`midweek`, `weekend`) | |
| `week_of` | date | not null, check it's a Monday (`extract(isodow from week_of) = 1`) | The meeting week. Weekend notes show "Weekend of November 21–22" from it, so no meeting-day setting is needed |
| `outline_version` | integer | not null, default 1 | Which outline built it |
| unique index | | (`user_id`, `kind`, `week_of`) | One note per meeting per person per week; "Start notes" can't make a duplicate |

`MeetingNote#program_url` → `https://wol.jw.org/en/wol/meetings/r1/lp-e/#{week_of.cwyear}/#{week_of.cweek}` (ISO week; confirmed: week 27 of 2026 is 29 June–5 July).

### `MeetingNote::Part`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `meeting_note_id` | uuid | FK → meeting_notes, not null, `on_delete: :cascade` | |
| `key` | string | not null | One of the outline's part keys for the note's kind and version (validated in the model) |
| `title` | string | nullable, `encrypts :title` | Talk title, Living as Christians part title, Public Talk title, Watchtower article title |
| `speaker` | string | nullable, `encrypts :speaker` | Public Talk only. Another person's name, so it's encrypted |
| `position` | integer | not null | Order within the note |
| notes | Action Text | `has_rich_text :notes, encrypted: true` | Lexxy, same setup as family study notes |

Parts that don't repeat are unique per note (validated in the model; a partial unique index on (`meeting_note_id`, `key`) where `key <> 'living_part'` backs it up). A new note creates its fixed parts up front, so the edit page is one form.

### `MeetingNote::Gem`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `meeting_note_id` | uuid | FK → meeting_notes, not null, cascade | |
| `scripture` | string | not null | As typed, e.g. "Isaiah 41:10" |
| `book_number` | smallint | not null, check between 1 and 66 | Bible order for the later gems page |
| `chapter` | smallint | not null, check > 0 | |
| `verse_start`, `verse_end` | smallint | nullable | "41:10" or "41:10-13"; a whole chapter leaves them null |
| `insight` | text | `encrypts :insight` | What the person found; personal |
| `position` | integer | not null | |

`Scripture` (a PORO in `app/models/scripture.rb`) parses references with the 66 English book names and common abbreviations ("Isa", "Ps", "1 Pet"). An unparseable reference is a validation error on the field: "Use a reference like Isaiah 41:10."

### `MeetingNote::Sharing`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `meeting_note_id` | uuid | FK, not null, cascade | |
| `household_id` | uuid | FK → households, not null, cascade | |
| `created_at` | datetime | | When it was shared |
| unique index | | (`meeting_note_id`, `household_id`) | |

Sharing is a record, not a flag (CLAUDE.md, State as Records). Stopping deletes it.

**Who can see a shared note:** active members of that household, and only while the author is still an active member there.

**Leaving ends a share for good.** Memberships are deactivated, not deleted, so someone can rejoin later. If shares only depended on the author's membership being active, rejoining would quietly make every old share visible again, including anything the author wrote while away. So:

1. `Membership#deactivate` also deletes the person's meeting-note sharings into that household, in the same transaction (an explicit step in the existing method, not a callback). After rejoining, a note is private again until the author shares it again.
2. `MeetingNote.shared_with(household)` still joins sharings to the author's active membership there, as a second guard, so a sharing row can never show while the author is inactive.

## Who can do what

| Action | Author | Member of a household it's shared with | Anyone else |
| --- | --- | --- | --- |
| List, open, edit, delete | yes | no | no (404) |
| Read | yes | yes, read-only | no (404) |
| Share with / stop sharing in the current household | yes, if an active member there | no | no |

A note that isn't visible is a 404, never a 403 (CLAUDE.md, Scoping). Children with a login keep and share their own notes like anyone else.

`MeetingNotePolicy` receives the membership: `show?` is the author, or a note shared with `membership.household` whose author is still active there; `update?`/`destroy?`/sharing are the author only.

## Pages

All under `/:household_id` in the app shell, with "Meeting notes" (`note` icon) in the sidebar's **Mine** group. The household in the URL decides only which household a share goes to and which "Shared" tab you see; your own notes are the same in every household.

| Page | Route | What's on it |
| --- | --- | --- |
| Meeting notes | `GET /:household_id/meeting_notes` | Frame `notes-list.png`. Subhead "Meeting notes". **This week:** a card for Life and Ministry and one for the Weekend meeting, each with a short summary ("2 gems, 3 parts with notes" or "Not started") and Open notes / Start notes. **My notes** tab: earlier notes, newest first, with a "Shared" Label where shared. |
| Shared in this household | `GET /:household_id/shared_meeting_notes` | The second tab: notes shared into this household by any member, with the author's name |
| Start a note | `POST /:household_id/meeting_notes` (`kind`, `week_of`) | Finds or creates the author's note for that week (`create_or_find_by` on the unique index), then redirects to it |
| A note (author) | `GET /:household_id/meeting_notes/:id` and `edit` | Frames `life-and-ministry-note.png`, `weekend-note.png`. Breadcrumbs, `h1` "Life and Ministry" or "Weekend meeting", a "Private" or "Shared with <household>" Label, the week, the wol.jw.org link, sections and parts from the outline, "Save notes". Share or Stop sharing in the header |
| A note (shared, read-only) | same URL, for a member it's shared with | Frame `shared-note-read-only.png`. "Shared by <author>" Label, a line saying it's read-only, empty parts hidden, gems as a list |
| Share / stop sharing | `POST` / `DELETE /:household_id/meeting_notes/:id/sharing` (`MeetingNotes::SharingsController`) | Frame `share-dialog.png`: a Primer Dialog explaining who will see it, then "Share note" |

**Editing:** one form per note. Titles, speaker and gems are Primer form inputs; each part's notes are a Lexxy `rich_text_area` (the approved exception in CLAUDE.md, Forms). Gems and Living as Christians parts are added and removed in the page with a small Stimulus controller (`accepts_nested_attributes_for` with `_destroy`); no full reload. The save hint under the button says "Only you can see this note." or "Members of <household> can read this note."

## Traps

- Everything a person types is encrypted: part notes, titles, the speaker's name, gem insights. Encrypted columns can't be searched or sorted in SQL, so the one exception is a gem's reference (`scripture`, `book_number`, `chapter`, `verse_*`), which isn't personal and is needed for Bible order.
- The household in the URL isn't the note's owner. Always load notes through `Current.user.meeting_notes` (author) or `MeetingNote.shared_with(Current.household)` (shared), never by id alone.
- Turbo Stream updates on a shared note must never be broadcast to household members while the author is editing; there are no live updates in NOTES-01.
- A person in two households sees their notes in both, but each share belongs to one household.
- Rejoining a household must not bring old shares back (see "Leaving ends a share for good").

## States each story checks

- Kind: Life and Ministry, Weekend
- Empty note, partly filled, full; zero, one and several gems; two Living as Christians parts
- Private, shared, shared then the author left the household, left and rejoined
- Viewer: author, another adult, a child, a non-member (404)
- Desktop and phone; light and dark
