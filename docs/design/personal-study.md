# Personal study

A place for each person's own research. Each study is one topic, with a conversation where the AI answers questions only from jw.org and wol.jw.org, and the person's own notes beside it. Stories live under the **PSTUDY-01** epic. It builds on `docs/design/ai.md` (read that first), `docs/design/tags.md` and `docs/design/scripture-links.md`.

Frames in `docs/design/personal-study/` (README there). Mockups are in the "Personal study" row on the design canvas.

## Decisions (Casey, 16 Nov)

- **A study holds a conversation and notes**, grouped into **collections** (folders), with the person's **tags** on top (`docs/design/tags.md`).
- **Studies are kept until the person deletes them.** The 7-day deletion in `docs/design/ai.md` stays for family study drafts only.
- **30 questions per person per day**, from midnight in the person's own time zone (`users.time_zone`). When they haven't set one, `user.limit_time_zone` falls back to a stable choice that doesn't change with the household they're asking from: the time zone of the household of their oldest active membership, or UTC if they have none. So switching households can't restart the day.
- **Older children can use AI if a head allows it,** with a switch per child in Household settings. Heads who allow it can read everything in that child's personal studies, and the child is told so.
- **Answers follow `docs/design/ai.md`:**
  - only jw.org and wol.jw.org
  - the AI's own words, with titles and links, never copied text
  - when the publications don't address something, the answer says so instead of guessing

## Who can do what

| | Head | Adult | Child, AI allowed | Child, not allowed |
| --- | --- | --- | --- | --- |
| Studies, collections, notes and tags | yes | yes | yes | yes |
| Ask the AI | yes | yes | yes | no ("Ask a head to turn on AI for your personal study.") |
| Read a child's studies | heads who allowed it | no | no | no |

The AI needs the person's own acceptance of the AI terms (`Ai::Acceptance`, `docs/design/ai.md`), children included.

`User#may_ask_study_ai?` is true when the person has an active membership as head or adult, or an active child membership with a study AI grant. It looks across all their households, because personal study belongs to the person and not to one household.

## Models

### `PersonalStudy`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | Personal; follows the person |
| `collection_id` | uuid | FK → collections, nullable, `on_delete: :nullify` | One folder, or none. Must be a collection used in personal study |
| `chat_id` | uuid | FK → chats, not null, unique | The conversation (`purpose: personal_study`) |
| `title` | string | not null, 1 to 120 characters | |
| `last_asked_at` | datetime | nullable | For sorting the list |

- `has_rich_text :notes, encrypted: true`, with `ScriptureLinkable` so references in notes become scripture links on save
- `include Taggable`
- `has_many :questions, -> { order(:created_at) }`
- `scope :recent_first` (by `last_asked_at`, then `updated_at`)
- `scope :matching(text)` matches the title, the collection's name or a tag name. Notes and conversations are encrypted, so search can't look inside them. The search box says "Search titles, collections and tags"

### `Collection` (shared with Notes)

Collections are the person's folders, shared between Personal study and Notes (`docs/design/notes.md`). Casey's decision (16 Nov): a base set of collections used by both, plus collections that belong to just one.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | Personal |
| `name` | string | not null, 1 to 40 characters, unique with `user_id` | |
| `used_in` | string | not null, default `both`, check in (`both`, `studies`, `notes`) | Where it appears |
| `position` | integer | not null | Order in the list |

- `scope :for_studies` (`both`, `studies`) and `scope :for_notes` (`both`, `notes`)
- A study's `collection` must be `for_studies`, and a note's must be `for_notes`. Either way it must belong to the same person (validations)
- On create, move or save, the collection is looked up through `Current.user.collections`, so another person's collection id is a 404, never attached
- Each page lists only its own collections. A shared one shows a small "shared" icon labelled "Shared with Notes" (or "Shared with Personal study"), and the line under the list reads "Also used in Notes"
- **New collection** (frame `docs/design/notes/notes-new-collection.png`): Name, then "Use in" with "<this section> and <the other>" (the default) or "<this section> only"
- **Changing `used_in`** away from a section is refused while that section still has things in the collection: "3 notes are in this collection. Move them first."
- **Deleting a collection** keeps everything in it; they just leave the folder

### `PersonalStudy::Question`

One question and its answer.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `personal_study_id` | uuid | FK, not null, `on_delete: :cascade` | |
| `user_id` | uuid | FK → users, not null | Who asked; the daily limit is per person |
| `prompt` | text | not null, encrypted, 1 to 1,000 characters | |
| `status` | string | not null, check in (`asking`, `answered`, `off_topic`, `flagged`, `failed`, `stopped`) | |
| `answer` | jsonb | encrypted, nullable until answered | The checked reply fields |
| `sources` | jsonb | not null, default `[]` | `[{url, title}]` that passed `Ai::SourceLink` |

- **The daily count reads a usage ledger, not the questions.** `Ai::Use` (`ai_uses`: `user_id` FK not null, `purpose` string not null, `question_id` FK → personal_study_questions, nullable, unique, `on_delete: :nullify`, `created_at`) gets a row in the same transaction that creates a question.
  - When the question ends `failed` or `flagged`, `question.use` (found by `question_id`, never by matching person and purpose) is deleted, so it doesn't count.
  - Deleting a study deletes its questions, and the database nulls their uses' `question_id`, so the rows stay and still count. A use with no question is never deleted except by the purge.
  - The count is `user.ai_uses.personal_study.where(created_at: midnight..)`, with midnight in the time zone above.
  - Rows older than 2 days are purged daily.
- The reply schema (`Ai::Purpose::PersonalStudyAnswer`):
  - `off_topic` (boolean)
  - `not_found` (boolean) and `not_found_note` (string): "I couldn't find jw.org or wol.jw.org…"
  - `paragraphs` (0 to 5 strings, each 1 to 600 characters). Scripture references are written inline as plain text. Blank or whitespace-only paragraphs are removed before any other check
  - **Order of the checks:** `off_topic` comes first. An off-topic reply ends `off_topic`, shows the refusal, keeps its use (it counts, as in `docs/design/ai.md`), and skips the minimum.
  - **Minimum after the checks**, for every other reply: at least one paragraph, or `not_found` with its note. A reply that has neither after the copy check and link checks ends `failed` ("Couldn't answer right now. Try again."), and its use is deleted
  - `next_questions` (0 to 3 strings, each 120 characters at most)
- After the checks in `docs/design/ai.md`, each paragraph's references are found with `Bible::Linker` and rendered as scripture links.

### Asking

- `study.ask(prompt, by: user)` runs inside `user.with_lock`:
  - refuses with `:limit` at 30
  - refuses with `:not_allowed` unless `may_ask_study_ai?` and `accepted_ai_terms?`
  - otherwise creates the question (`asking`) and calls `answer_later`
- `PersonalStudy::AnswerQuestionJob` → `question.answer_now`, the same shape as `FamilyStudy::Draft#write_now` (`docs/design/family-studies.md`):
  1. moderation
  2. `chat.ask_within_purpose`, with **progress lines only** broadcast to the question's own stream
  3. the checks (off topic, copy check, `Ai::SourceLink`, references)
  4. the final status and answer, written with a conditional update that applies only while `asking`
  5. one broadcast of the result, only if this job's write applied and the status is unchanged

  The chat keeps earlier questions and answers, so follow-ups build on them, just as the person's Claude conversations do.
- **Who's asking shapes the answer.** When the asker is a child (their membership role in the household they're viewing), the instructions add: write simply, for a young reader. The schema and every check stay the same.

### Children: `Membership::StudyAiGrant`

State as a record: `membership_id` (FK, unique, `on_delete: :cascade`) and `granted_by_id` (FK → users), with `created_at`.

- Only heads create or destroy one, and only for a child membership with a login (frame `child-study-ai-setting.png`):
  - `POST /:household_id/memberships/:membership_id/study_ai_grant`
  - `DELETE` the same path

  It lives in Household settings → Children → "Personal study with AI".
- **Turning it off** stops new questions. The child keeps their studies, notes and answers. Heads stop seeing them.
- **What heads see.** A head of a household where the child has a grant can read the child's studies, read-only: the list, each conversation with its answers and sources, the notes and the tags.
  - `GET /:household_id/members/:member_id/personal_studies` and `…/personal_studies/:id` (`Members::PersonalStudiesController`)
  - `ChildStudyPolicy#show?` requires the viewer to be a head here, and the member to be an active child here with a grant
  - Anyone else gets a 404
- **The child is told.** Their Personal study page shows a Primer Banner: "Your parents can read your personal study, including what you ask and your notes."
- **Leaving the household** destroys the membership, and with it the grant. The child's studies stay with them.

## Pages and routes

Under `/:household_id` for the household layout. The data is always found through `Current.user`.

| What | Route | Frame |
| --- | --- | --- |
| Studies and collections | `GET /:household_id/personal_studies` (`?collection=`, `?tag=`, `?q=`) | `personal-studies.png` |
| New study | `POST /:household_id/personal_studies` (title, optional collection, optional first question) | |
| A study | `GET /:household_id/personal_studies/:id` | `personal-study.png` |
| Rename, move, edit notes | `PATCH /:household_id/personal_studies/:id` | |
| Delete | `DELETE /:household_id/personal_studies/:id`, after a Primer dialog | |
| Collections | `resources :collections, only: %i[ create update destroy ]` (shared with Notes) | |
| Ask | `POST /:household_id/personal_studies/:id/questions` | |
| Stop | `DELETE /:household_id/personal_studies/:id/questions/:question_id` (sets `stopped` while asking) | |
| Save an answer to notes | `POST …/questions/:question_id/note_saving` (`resource :note_saving, only: :create`) | |
| Tags | `docs/design/tags.md` | |
| On a phone | the same page, with Conversation, Notes and Sources tabs | `phone-personal-study.png` |

### The study page

- **Header.** Breadcrumb (Personal study / the collection), the title, "Started … · N questions · N pages linked", the tag editor, "Plan a family study from this" (heads and adults, in a household with family studies), and a menu with Rename, Move to collection and Delete.
- **Conversation.** Each question, then its answer card:
  - "From jw.org and wol.jw.org"
  - the paragraphs with linked references
  - "Pages used" with each page as a link (title and host)
  - "Save to notes", and "Save as a note", which makes a new note in Notes (`docs/design/notes.md`, added by NOTES-01)
  - "Check each point against its page."

  A `not_found` answer opens with its note in a muted box. "Keep digging" shows the next questions as chips that fill the ask box.
- **Ask box.** "Ask a follow-up", with the line "Answers use only jw.org and wol.jw.org, in the AI's own words, with links. N of 30 questions left today." Without AI access, the line explains why and the box is disabled. Without accepted terms, the first-use notice from `ai.md` appears instead.
- **My notes.** The Lexxy editor with the Scripture button (`docs/design/scripture-links.md`), saved with "Save notes".
- **Sources in this study.** Every page linked across the study's answers, without duplicates, with the line "Titles and links only. Open a page to read it on jw.org."

### Save to notes

`question.save_to_notes` appends to the study's notes:
- the answer's paragraphs, rendered from our own partial with escaped text and references as plain text (`ScriptureLinkable` links them on save)
- then "Pages:" and the source links

The person can edit it like any note. It's their record now, so it's kept even if the question is later deleted.

### Plan a family study from this

It links to the household's Schedule a family study page with `?from_study=:id`. The AI panel opens on Describe with the study's title and its last question filled in (`docs/design/family-studies.md`, AI helper). Nothing is sent until the person chooses "Draft outline", and it counts toward the household's drafts, not the person's questions.

## Changes to `docs/design/ai.md`

This epic makes these changes, in the same PR as this doc:
- `chats.purpose` adds `personal_study`
- retention becomes per purpose (`Ai::Purpose#keep_for`): 7 days for `family_study_draft`, and kept until deleted for `personal_study`. The purge job only deletes purposes with a `keep_for`
- children: personal study is the first feature with a decision for children (above)
- limits can be per person in the person's time zone, as well as per household, and per-person limits count `Ai::Use` rows

## Traps

- **Search can't read encrypted text.** Search titles, collection names and tags only, and say so in the box.
- **A head's view is read-only and narrow.** It shows only the child's personal studies, only in a household where the head is a head and the child has a grant. Never the child's meeting notes or goals.
- **Grants are per membership.** A child in two households may have AI allowed in one and not the other. `may_ask_study_ai?` looks across all of them; the head's view looks only at its own household.
- **Don't count questions in UTC.** Use `user.time_zone`.
- **Deleting a study can't refund questions.** The limit reads `Ai::Use`, never `PersonalStudy::Question` (above).
- **The answer card is untrusted text.** Escape every field. References are linked by `Bible::Linker` after escaping, never by trusting markup from the reply.
- **Never show `cited_text`**, and never fetch jw.org (`docs/design/ai.md`).
- **The chat grows.** Send at most the last 10 questions and answers as context, so long studies stay within the model's limits and cost.

## States each story checks

- Person: head, adult, child with a grant, child without one, a head viewing a child's studies, another head without a grant here (404), a non-member (404)
- Limit: 0, 29 and 30 used; a new day in the person's time zone; a deleted study's questions still counted
- Answer: good, not found, off topic, flagged, failed, stopped, with a link not in the search results, with copied text
- Study: no questions yet, no notes, in a collection or none, with tags
- Desktop and phone; light and dark
