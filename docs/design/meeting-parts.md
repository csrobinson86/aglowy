# Meeting parts

A place for each person to keep and prepare their student parts in the midweek meeting's **Apply Yourself to the Field Ministry** section. A part holds what was assigned, the person's own preparation, and what they were counselled on afterwards. Heads and adults can ask the AI for an outline or sample wording, built only from jw.org and wol.jw.org. Stories live under the **PARTS-01** epic.

It builds on `docs/design/ai.md` (read that first), `docs/design/meeting-notes.md` (sharing), `docs/design/calendar.md` and `docs/design/scripture-links.md`.

Frames in `docs/design/meeting-parts/` (README there). Mockups are in the "Meeting parts" row on the design canvas.

## Decisions (Casey, 17 Nov)

- **Only the assignments in Apply Yourself to the Field Ministry.** Starting a Conversation, Following Up, Making Disciples, Explaining Your Beliefs and Talk. Bible reading, talks in other sections, and weekend parts aren't in this version.
- **The AI helps four ways:**
  - **an outline:** main points, scriptures, and ideas for the opening and the close
  - **sample wording:** a sample conversation, or a talk in full sentences, for the person to put into their own words
  - **changes:** after a draft, the person can ask for a change ("a shorter opening")
  - **fitting the time:** the AI aims at the part's minutes, and the page shows about how long the words would take to say
- **Private unless shared.** A part belongs to the person. Nobody else sees it until they share it with a household, as with a meeting note.
- **No AI on children's parts.** Children keep and prepare parts like anyone else, without the AI panel. There's no switch to turn it on.

What follows from these, and needs Casey's OK in the PR:

- **15 AI requests per person per day** for meeting parts (each outline, wording or change is one), counted like personal study.
- **AI drafts are deleted 60 days after they're made.** What the person put into their preparation stays.
- **A child without a login can't have a part yet.** Parts belong to whoever adds them. A parent adding one for a child comes later.
- **Counsel is never shared.** Sharing a part shows what it is and the preparation, not the "After the meeting" notes.

## What PARTS-01 builds, and what comes later

| In PARTS-01 | Later |
| --- | --- |
| Parts: add, edit, delete; the list, coming up and earlier | Bible reading and other sections' parts; weekend parts |
| Preparation with scripture links, and counsel afterwards | A parent adding a part for a child without a login |
| About how long the preparation takes to say | A practice timer |
| Sharing a part with a household, read-only | A reminder before the meeting (a notification kind) |
| Parts on the calendar, in Today on Home and on that week's meeting note | Parts in the phone calendar link |
| AI outline, sample wording and changes, for heads and adults | Tags on parts; looking back at counsel across parts |

## The assignments

Checked against the jw.org meeting instructions (S-38-E 8/26). The meeting workbook gives each part's time, source and study point; the person types those in. Aglowy doesn't copy the workbook.

| `kind` | Shown as | Form | The other speaker in sample wording |
| --- | --- | --- | --- |
| `starting_a_conversation` | Starting a Conversation | demonstration | Householder |
| `following_up` | Following Up | demonstration | Householder |
| `making_disciples` | Making Disciples | demonstration | Bible student |
| `explaining_beliefs_demonstration` | Explaining Your Beliefs, "Demonstration" in its details | demonstration | Other person |
| `explaining_beliefs_talk` | Explaining Your Beliefs, "Talk" in its details | talk | none |
| `talk` | Talk | talk | none |

- `MeetingPart::Kind`, a PORO in `app/models/meeting_part/kind.rb`, holds this table: the label, `demonstration?` or `talk?`, and `other_speaker`.
- **Aglowy doesn't decide who may give a part.** The congregation assigns parts. The form offers every kind to everyone.
- **Settings** (`house_to_house`, `informal_witnessing`, `public_witnessing`) are optional on any part. The workbook gives one for Starting a Conversation and Following Up.

## Who can do what

| Action | The person (head, adult or child) | A member of a household it's shared with | Anyone else |
| --- | --- | --- | --- |
| Add, edit and delete their parts | yes | no | no |
| Read a part's details and preparation | yes | yes, read-only | no (404) |
| Read the counsel | yes | no | no |
| Share with, or stop sharing with, the household in the URL | yes, if an active member there | no | no |
| Use the AI on their own part | heads and adults only | no | no |

- "Head or adult" means `user.may_prepare_parts_with_ai?`: an active membership as head or adult in any household. Parts are personal, so it doesn't depend on the household in the URL. Someone who is a child in every household never has it.
- `MeetingPartPolicy` follows `MeetingNotePolicy`: `show?` is the owner, or a part shared with `membership.household` whose owner is still active there. `update?`, `destroy?` and sharing are the owner only. `draft?` is the owner with `may_prepare_parts_with_ai?`.
- A part that isn't visible is a 404, never a 403.

## Models

### `MeetingPart`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | Personal; follows the person |
| `kind` | string | not null, check in the six kinds above | |
| `meeting_on` | date | not null | The day of the meeting |
| `minutes` | integer | not null, check between 1 and 15 | The part's time; the whole section is 15 minutes |
| `setting` | string | nullable, check in the three settings | |
| `topic` | text | not null, encrypted, 1 to 300 characters | What it's about, in the person's words |
| `study_point` | string | nullable, encrypted, 80 characters at most | "th study 3", "lmd lesson 1 point 3" |
| `assistant` | string | nullable, encrypted, 80 characters at most | A name only. It's someone else's, so nothing more is kept |
| `counsel` | text | nullable, encrypted, 2,000 characters at most | After the meeting |

- `has_rich_text :preparation, encrypted: true`, with `ScriptureLinkable`, so references become scripture links on save
- `include Shareable`, with `MeetingPart::Sharing` (`meeting_part_id`, `household_id`, unique together), like `MeetingNote::Sharing`. Leaving a household ends the shares there for good (`Membership#deactivate`, as for notes and goals)
- `has_many :drafts` (below), `dependent: :destroy`
- `scope :coming_up, ->(today)` (`meeting_on >= today`, soonest first) and `scope :earlier` (newest first). "Today" is the date in `user.calendar_time_zone` (`docs/design/calendar.md`)
- `part.week_of` is the Monday of `meeting_on`'s week, for the wol.jw.org program link and the meeting note (`MeetingNote`, `docs/design/meeting-notes.md`)
- `part.spoken_length` is `MeetingPart::SpokenLength.new(preparation.to_plain_text)`

### `MeetingPart::SpokenLength`

A PORO that says about how long text takes to say: words ÷ 130 a minute, rounded to 10 seconds, at least 10 seconds for any words at all.

- `to_s`: "About 50 s to say", "About 2 min 40 s to say"; blank text gives nothing, and the line isn't shown
- `over(minutes)`: the seconds over the part's time, or nil
- `SpokenLength.target_words(minutes)`: the words to aim an AI draft at
- `WORDS_PER_MINUTE = 130` and `READ_SECONDS = 20` (one scripture read aloud) live here, so the page, the Stimulus controller and the AI's target all use the same numbers

### `MeetingPart::Draft`

One AI request and its checked reply.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `meeting_part_id` | uuid | FK, not null, `on_delete: :cascade` | |
| `chat_id` | uuid | FK → chats, not null, unique, `on_delete: :cascade` | Its own conversation: one request and one reply, as a family study draft has. The purge deletes the chat, and the draft goes with it |
| `user_id` | uuid | FK → users, not null | Who asked; the limit is per person |
| `kind` | string | not null, check in (`outline`, `wording`) | What was asked for |
| `request` | text | nullable, encrypted, 500 characters at most | "Anything it should know?", or the change asked for |
| `revises_id` | uuid | FK → meeting_part_drafts, nullable, `on_delete: :nullify` | The draft a change, or the wording, was built on. Only for the links to it; the purge nulls it |
| `revised_result` | jsonb | encrypted, nullable | A copy of that draft's checked `result`, taken when the request is made. The job sends this copy and never reads `revises`, so a purge between the request and the job can't change what's sent |
| `status` | string | not null, check in (`drafting`, `drafted`, `off_topic`, `flagged`, `failed`, `stopped`, `discarded`) | |
| `result` | jsonb | encrypted, nullable until drafted | The checked reply fields |
| `sources` | jsonb | not null, default `[]` | `[{url, title}]` that passed `Ai::SourceLink` |

- `belongs_to :chat, dependent: :destroy`, so deleting a part deletes its drafts' chats with them, not at the next purge.
- `revises` must be a `drafted` draft of the same part: of the same kind for a change, or an outline for sample wording. `part.draft` checks that and copies its `result` into `revised_result` in the same lock.
- `Ai::Use` gains `meeting_part_draft_id` (FK, nullable, unique, `on_delete: :nullify`), used exactly as `question_id` is for personal study: made with the draft, deleted when the draft ends `failed` or `flagged`, kept when the draft or its part is deleted.
- `draft.spoken_length` counts the words of the result, plus `READ_SECONDS` for each scripture marked to read.
- `draft.preparation_html` builds notes from our own ERB partial with escaped fields, as `FamilyStudy::Draft#notes_html` does.

## Pages and routes

Under `/:household_id` in the household layout. The data is always found through `Current.user`, or through `MeetingPart.shared_with(Current.household)` for a shared part.

```ruby
resources :meeting_parts do
  resource :sharing, only: %i[ create destroy ], module: :meeting_parts
  resources :drafts, only: %i[ create show destroy ], module: :meeting_parts
end
resources :shared_meeting_parts, only: :index
```

| What | Route | Frame |
| --- | --- | --- |
| Meeting parts | `GET /:household_id/meeting_parts` | `meeting-parts.png` |
| Shared in this household | `GET /:household_id/shared_meeting_parts` | |
| Add or edit a part | `new`, `create`, `edit`, `update`, in a Primer `Dialog` | `part-new.png` |
| A part | `GET /:household_id/meeting_parts/:id` | `part-prepare.png`, `part-child.png`, `part-dark.png`, `phone-part.png` |
| Save preparation and counsel | `PATCH /:household_id/meeting_parts/:id` | |
| Delete | `DELETE`, after a Primer dialog | |
| Share, stop sharing | `POST` and `DELETE /:household_id/meeting_parts/:id/sharing` | |
| A shared part | the same `show`, read-only | `part-shared.png` |
| Ask the AI | `POST /:household_id/meeting_parts/:id/drafts` | `part-ai-outline.png`, `part-ai-wording.png` |
| A draft (reload, an earlier version) | `GET …/drafts/:draft_id` | |
| Stop or discard | `DELETE …/drafts/:draft_id` | |

### The sidebar

"Meeting parts" joins the Mine group, after Notes (`docs/design/app-shell.md`), with the `comment-discussion` Octicon. Everyone sees it, children too.

### The list

- The header: "Meeting parts", "Your student parts in Apply Yourself to the Field Ministry. Private unless you share them.", and "Add a part".
- A Mine / "Shared in <household>" switch, as on the Meeting notes tab.
- **Coming up** (soonest first) and **Earlier** (newest first). Each row: the date, the kind, the topic on one line, then the weekday, minutes, setting and assistant, and a "Private" or "Shared" Label.
- Empty: a Primer `Blankslate`, "No parts yet", "When you're given a part in Apply Yourself to the Field Ministry, add it here to prepare.", and "Add a part".

### Add or edit a part

A Primer `Dialog` with `MeetingPartForm`:

- **Part:** a select of the six kinds, with Explaining Your Beliefs listed twice, "(demonstration)" and "(talk)"
- **Meeting date:** defaults to the household's next midweek meeting day (`docs/design/meeting-helper.md`, Meeting times), with the hint "Your next midweek meeting."; blank when no meeting times are set
- **Minutes**
- **Setting** (optional): House to house, Informal witnessing, Public witnessing
- **What it's about:** "Type it in your own words. Aglowy doesn't copy the workbook."
- **Study point** (optional) and **Assistant** (optional)

A refused save re-renders the dialog with `:unprocessable_content`.

### A part

- **The header:** breadcrumb, the kind as the `h1`, a "Private" or "Shared with <household>" Label, then the date ("Thursday, December 3 · Midweek meeting · in 16 days"). Share, Edit and Delete for the owner.
- **The part:** time, setting, study point and assistant; what it's about; "This week's program on wol.jw.org" and "My notes for this meeting" (the viewer's own note for that week, `POST /:household_id/meeting_notes` with `kind: midweek` and `week_of`).
- **Preparation:** the Lexxy editor (an approved exception, `CLAUDE.md`). Under it, the time line: "**About 50 s to say** · your part is 3 min. It counts the words above; scriptures you read aloud add to it." Over the time, it adds an `alert` Octicon and "40 s over your 3 min", so it isn't colour alone. A small Stimulus controller, `spoken-length`, updates the line as the person types, from `WORDS_PER_MINUTE`.
- **After the meeting:** "Counsel, and what to work on next", with "Only you see this, even when the part is shared."
- **Save** saves the preparation and the counsel together.
- **Prepare with AI** sits beside these on a desktop, for heads and adults. On a phone it's a button beside Save that opens a full-screen dialog, as the family study helper does.
- **A shared part** shows the header (with "shared by Daniel Rivera"), the part and the preparation, read-only. No counsel, no AI panel, no buttons.

### Sharing

Share opens the same dialog as a meeting note's: "Share with the Rivera household?", what they'll see ("the part and your preparation, not your counsel"), and any other household of yours that won't see it. Sharing makes a `shared_with_you` notification for the other members (`docs/design/notifications.md`): "Daniel shared a meeting part", then "Talk · Thursday, December 10".

### On the calendar and the meeting note

- **Calendar.** `Household::Calendar` gains meeting parts: the viewer's own parts and the parts shared with this household, each on its `meeting_on`, at the midweek meeting's time when that day is the household's midweek day, otherwise all day. Titles are "Your part: Starting a Conversation" and "Daniel: Talk". Each links to the part. They're drawn with the meetings and aren't a filter of their own. Today on Home shows them because it reads the same calendar.
- **The meeting note.** The viewer's own midweek note for that week shows a line under its header for each part they have that week, soonest first: "Your part this week: Starting a Conversation, 3 min". Each line links to its own part. It never shows on a note someone else shared.

## Prepare with AI

Everything in `docs/design/ai.md` applies. This section only adds to it.

### The purpose: `Ai::Purpose::MeetingPart`

- **Its one job:** help prepare a student part in Apply Yourself to the Field Ministry. Anything else is `off_topic` and gets "This helper only prepares your meeting part."
- `instructions` in `config/ai/meeting_part.md`; `allowed_hosts` as always; `max_searches` 5
- `daily_limit` 15 per person, counted from `Ai::Use` rows in the person's time zone under the person's lock, as personal study is
- `keep_for` 60 days:
  - Each draft has its own chat, so the daily purge that family study drafts use (`Ai::PurgeExpiredChatsJob`) deletes a chat 60 days after it was made, and its draft goes with it. Each request and its reply are kept 60 days from when the request was made, however many newer drafts the part has.
  - **A draft that revises another keeps a copy of it,** in its `revised_result` and in its chat's saved request. That's a change, which copies the draft it changes, and sample wording, which copies its outline. The copy goes with the newer draft, 60 days after that draft was made, so it can outlast the older one. This is the only way a draft's text is kept past its own 60 days, and it happens only because the person asked for something built on that draft.
  - What the person used is already in their preparation, which is theirs and stays.
- No `context_exchanges`: a chat holds one request and one reply, so there's no history to trim.
- **What's sent:** the part's kind, minutes, setting, topic and study point, the target length in words (`SpokenLength.target_words(minutes)`: four fifths of `minutes × WORDS_PER_MINUTE`, which leaves room for reading scriptures and for pauses), and `request`. A change, or sample wording written from an outline, also sends the draft it `revises` (How a request runs). **Never** the preparation, the counsel, the assistant's name, the person's name or the household (`docs/design/ai.md`, safety measure 7). The panel says so.
- **Moderation** runs on the topic, the study point and the request together.

### The reply

One schema with both shapes. The draft's `kind` says which one the instructions ask for; the other is left empty and ignored.

- `off_topic` (boolean)
- `outline`:
  - `aim`: one sentence on what the listener should take away
  - `opening`
  - `points`: 1 to 3, each with `heading`, `scripture` (a reference or empty) and `explain`
  - `question`: one to ask, or to leave for next time; empty for a talk
  - `close`
  - `study_point`: how to work on the study point the person typed; empty when they typed none
- `wording`:
  - `lines`: 2 to 20, each with `speaker` (`you` or `other`; always `you` in a talk), `text`, and `read` (a scripture to read aloud after the line, or empty)
- Every string is 500 characters at most.
- Scriptures are references only. The instructions say never to write verse text, and a line that reads a scripture says so with `read`, shown as "(Read Psalm 37:10, 11)". `scripture` and `read` each go through `Bible::Reference.parse`, and one that doesn't parse is dropped while its point or line stays (`docs/design/ai.md`, Scripture references).
- **Minimum after the checks:** an outline needs its aim and one point; wording needs 4 lines for a demonstration and 2 for a talk. Less than that ends `failed` ("Couldn't make a draft this time. Try again."), and its use is deleted.

### The panel

Frames `part-prepare.png`, `part-ai-outline.png` and `part-ai-wording.png`. The other states look like the family study helper's, and reuse its frames in `docs/design/family-studies/`.

| State | What it shows |
| --- | --- |
| First use | The AI notice and "Turn on AI drafts" (`ai-terms.png`, `Ai::Acceptance`) |
| Start | What it does and that it aims at the part's minutes; "What would help?" with An outline or Sample wording; "Anything it should know?" (optional, 500 characters); what's sent; "Draft outline" or "Draft wording"; "15 of 15 left today" |
| Drafting | Progress lines only, and Stop (`ai-searching.png`) |
| Outline | The outline with its time ("About 2 min 30 s to say"), the pages it used, the "AI can get things wrong" warning, "Use this outline" and "Write sample wording" |
| Wording | The lines, labelled You and Householder (or the kind's other speaker; no labels for a talk), with the time ("About 2 min 40 s to say, plus 1 scripture to read"), the warning "This is a sample to learn from. Put it in your own words, and check each point against its source.", "Use this wording" and "Back to the outline" |
| Ask for a change | Under any draft: three chips that fill the box (Shorter opening, Simpler words, A different scripture), a text box (300 characters) and "Change it". Under the box: "Sends the part's details, this draft and your change. Never your preparation." Then "Version 2 · See version 1", and Discard |
| Over the time | A draft more than 15% over the part's time adds: "This runs about 20 s over. Ask for a change to shorten it." It never asks again by itself |
| Limit reached | "You've used today's 15 requests", and when it resets (`ai-limit.png`) |
| Off topic | The refusal (`ai-refused.png`) |

### How a request runs

`part.draft(kind:, request:, revises:, by: user)` does this inside `user.with_lock`:

- refuses with `:limit` at 15, and with `:not_allowed` unless `may_prepare_parts_with_ai?` and `accepted_ai_terms?`
- makes the draft (`drafting`) with its own chat, its `Ai::Use` and, when it revises a draft, the copy in `revised_result`

Then, after the lock block returns, it calls `write_later` on a saved draft, as `FamilyStudy::Draft.start` and `PersonalStudy#ask` do. The job is queued in another database, so queuing it inside the lock could let a worker start before the draft is committed.

`MeetingPart::WriteDraftJob` → `draft.write_now`, the same five steps as `FamilyStudy::Draft#write_now` (`docs/design/family-studies.md`): moderation; `chat.ask_within_purpose` with progress lines only; the checks; the final status with a conditional update that applies only while `drafting`; one broadcast of the result.

- **A change** is a new draft of the same kind with `revises` set and the change as `request`. It counts as one request.
- **Write sample wording** is a new `wording` draft that `revises` the outline.
- **Both send the draft they revise.** The text sent adds `revised_result`: that draft's `result`, the fields the checks left and the person sees, copied when the request was made. It goes as plain text inside the same marked block as the person's own text (`docs/design/ai.md`, safety measure 3). The job reads only the copy, so it never runs a change without the draft the person chose, even if the purge deletes that draft first. So the AI changes the version on screen, whichever version that is, and never gets back a sentence the checks removed. What the person typed for an earlier version isn't sent again; the draft already reflects it.
- **Each draft runs in its own chat.** No request depends on an earlier chat, so an old draft can be purged without touching a newer one, and two drafts of one part never share a chat.
- **Use this outline** and **Use this wording** send nothing to the server. The `ai-draft` Stimulus controller appends `preparation_html` to the Preparation editor, and a "From an AI draft" Label shows beside the heading until the person edits it. The person still presses Save. Nothing records that AI was used.

### When a request doesn't finish

What counts toward the day's 15 is whether the draft still has its `Ai::Use`. `failed` and `flagged` delete it; every other status keeps it.

- **The queue refuses the job** (`perform_later` returns false, or Solid Queue raises `SolidQueue::Job::EnqueueError`): `write_later` ends the draft `failed` and deletes its use, as `PersonalStudy::Question::Answerable#answer_later` does for a question. (Family study drafts fail the same way, but have no `Ai::Use`: their limit counts drafts by status.) The panel shows the family study helper's "Couldn't make a draft right now. Try again in a moment."
- **The job raises,** at the provider or anywhere else: `failed`, and the use is deleted.
- **Stop** ends a `drafting` draft as `stopped` and keeps its use. A stopped request counts, as a stopped personal study question does, because the AI may already have been called.
- **Accepted gap: the app process dies after the draft is saved and before `write_later` runs.** No job exists, nothing retries it, and the draft stays `drafting`. The panel shows Drafting with Stop, so the person stops it and asks again, and that one request still counts for the day. Family study drafts and personal study questions have the same gap. It's too rare to earn a job that sweeps up old `drafting` rows; if it does happen, add one sweep for all three features.

## Elsewhere

- **`docs/design/ai.md`:** the `meeting_part` purpose, its limit and `keep_for`; safety measure 5 says what the quotation rule does and doesn't catch; safety measure 8 notes that meeting parts are heads and adults only.
- **`docs/design/app-shell.md`:** the Mine group gains Meeting parts.
- **`docs/design/calendar.md`:** meeting parts join what a calendar is put together from.
- **`docs/design/notifications.md`:** `shared_with_you` covers meeting parts.
- **`docs/product/vision.md`:** roadmap row 19, PARTS-01.
- **Seeds** (`db/seeds/`): two parts coming up and two earlier for the seeded head, one of them shared; one part for a seeded child with a login; one drafted outline and one drafted wording from saved replies, never a provider call.

## Traps

1. **Children never reach the AI.** The panel isn't rendered for them, and `Drafts` controllers check `draft?` on every action. Don't add a grant or a setting.
2. **Send only the part's five details, the request and, for a change or sample wording, the draft it revises.** Not the preparation, and not the assistant's name, even though both are on the same page. The draft sent is the copy of its checked `result` (`revised_result`), never what the person made of it in Preparation.
3. **Counsel never leaves the owner.** The shared view, the calendar and notifications never include it.
4. **No verse text.** The wording says "(Read …)" and stops. Two checks back the instructions up, and neither is complete:
   - `scripture` and `read` hold a reference or nothing. One that doesn't parse as a reference, verse text included, is dropped (`docs/design/ai.md`, Scripture references).
   - In every other field, the copy check's quotation rule (`docs/design/ai.md`, safety measure 5) removes a sentence holding a quotation of more than 5 words.
   - A quotation of 5 words or fewer, and verse text written without quotation marks, pass both. The copy check's overlap rule catches them only when 8 words in a row match an excerpt the search returned. Aglowy never fetches verse text, so it has nothing else to compare them against. Otherwise they rest on the instructions and on the warning shown with every draft.
5. **Don't show a draft's text while it's drafting,** and don't let a finished job override Stop (`docs/design/ai.md`, Traps).
6. **The time line is a guide.** Don't block a save, or an AI draft, for being over.
7. **A shared part is found through `MeetingPart.shared_with(Current.household)`,** which also checks the owner is still active there. Another household's part is a 404.
8. **Don't enforce who may give which part.** That's the congregation's decision, not Aglowy's.
9. **One chat per draft.** Don't run a change in the chat of the draft it revises. A shared chat would keep an old draft's text past its 60 days, and would hand the AI its own unchecked reply instead of the draft the person sees.

## States each story checks

- Person: head, adult, child with a login (no AI), a member reading a shared part, a non-member (404), not yet accepted the AI terms
- Part: each of the six kinds; with and without a setting, study point and assistant; coming up, today, earlier; shared, not shared, shared then stopped
- Time line: no words (hidden), under the time, over the time
- AI: an outline, wording for a demonstration and for a talk, a change (the draft it revises is sent, and it's the version shown), off topic, flagged, provider error, a quotation of more than 5 words (removed), a `scripture` or `read` that isn't a reference (dropped), too thin, stopped (still counts), the queue refusing the job (`failed`, doesn't count), 14 used and 15 used, a new day in the person's time zone
- Kept: a draft 61 days old goes with its chat while a newer draft of the same part stays; a change, and sample wording, that revises it keeps its copy and its chat, and all of that goes 60 days after the newer draft was made; a change still sends its copy when the draft it revises is deleted before the job runs; deleting a part deletes its drafts and their chats; the preparation stays either way
- Desktop and phone; light and dark
