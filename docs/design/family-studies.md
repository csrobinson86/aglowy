# Family studies

How a household schedules a family study, what each occurrence holds, and the pages for it. Read this before touching `FamilyStudy`, its sessions, its resources or their pages. Stories for the first build live under the **STUDIES-01** epic.

The data model was agreed in the users design ("Aglowy — Users Domain Model", planned models and gotchas 14–17 and 21–24). This document repeats what a builder needs and adds the decisions taken since. The mockup frames are in `docs/design/family-studies/`.

## What STUDIES-01 builds, and what comes later

| In STUDIES-01 | Later |
| --- | --- |
| Schedule a one-off or repeating study (daily, weekly, monthly, every N) | "All future sessions" edits that move the schedule (gotcha 16) |
| Sessions generated ahead, safe to rerun | Guests and invitations |
| Family studies list and a page per session | Reminders and notifications |
| Session notes in Lexxy, encrypted | AI study helper (AI-01, see "AI helper" below) |
| Link resources, and file resources (PDF, images) up to 25 MB | Attendance |
| Household storage quota, with a warning at 80% | Ending a repeating study (`ends_on` in the UI) |
| Next study and "Coming up" on the household home | |
| Edit or cancel one session ("this session only") | |

## Who can do what

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| See studies, sessions, notes and resources | yes | yes | yes |
| Schedule a study | yes | yes | no |
| Edit a session's topic, time or notes; add or remove resources | yes | yes | no |
| Cancel a session | yes | yes | no |

Everything is reached through `Current.household`; a study, session or resource from another household is a 404 (CLAUDE.md, Scoping).

## Models

### `FamilyStudy`: the arrangement

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null | |
| `frequency` | string | not null, default `once`, check in (`once`, `daily`, `weekly`, `monthly`) | One-off unless the creator picks a repeat |
| `interval` | integer | not null, default 1, check > 0 | "Every 2 weeks"; ignored when `once` |
| `starts_on` | date | not null | Date of the first session; weekly studies repeat on its weekday |
| `week_of_month` | smallint | check in (1, 2, 3, 4, 5, -1); required when `monthly` (check constraint) | 2 = second Tuesday, 5 = fifth (skips months without one), -1 = last (gotcha 17) |
| `time_of_day` | time | not null | Local time in the household's zone, not UTC (gotcha 14) |
| `duration_minutes` | integer | not null, default 60, check > 0 | **New (14 Nov):** the form has Starts and Ends, and Home shows "7:00 – 8:00 PM" |
| `ends_on` | date | nullable | Recurring only; open-ended when null. No UI in STUDIES-01 |
| `default_conductor_id` | uuid | FK → users, nullable | Copied onto each new session. No UI in STUDIES-01 |

### `FamilyStudy::Session`: one occurrence

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `family_study_id` | uuid | FK → family_studies, not null | Household is reached through the study |
| `recurrence_at` | datetime | not null, UTC | The slot the schedule produced; never changes, even when the session moves |
| `scheduled_at` | datetime | not null, UTC | When it actually happens |
| `topic` | string | nullable | Shown as "Topic not chosen yet" when blank |
| notes | Action Text | `has_rich_text :notes, encrypted: true` | Edited in Lexxy |
| `conductor_id` | uuid | FK → users, nullable | |
| `detached_at` | datetime | nullable | Set when edited "this session only" |
| `canceled_at` | datetime | nullable | Skips one session without touching the study |
| unique index | | (`family_study_id`, `recurrence_at`) | The generator can't duplicate a session, even a moved one (gotcha 21) |

A session's end is `scheduled_at + family_study.duration_minutes`.

### `FamilyStudy::Resource`: a link or a file on a session

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `session_id` | uuid | FK → family_study_sessions, not null | |
| `kind` | string | not null, check in (`link`, `file`) | |
| `url` | string | required for `link`; `http` or `https` only | Gotcha 23 |
| `file` | Active Storage attachment | required for `file` | PDF and images; 25 MB max |
| `title` | string | not null | Defaults to the file name or the link's host and path |
| `position` | integer | | Order on the session page |

Presence, type and size of the file are validated in the model (the attachment lives in Active Storage's tables, where a check constraint can't see it), and the size is also checked when the direct-upload blob is created (gotcha 24).

### Limits (one place each)

```ruby
# config/application.rb
config.x.family_studies.max_file_size     = 25.megabytes
config.x.family_studies.file_types        = %w[application/pdf image/png image/jpeg image/gif image/webp image/heic]
config.x.storage.household_quota          = 2.gigabytes
config.x.storage.warning_ratio            = 0.8
config.x.family_studies.minimum_horizon   = 3.months
```

## Scheduling rules

1. **Creating a study creates its first session** in the same transaction, with the form's topic, notes and resources on it. A repeating study gets its later sessions from the generator. Later sessions start with no topic.
2. **Each session's time is computed in the household's zone** (`households.time_zone`): `zone.local(date.year, date.month, date.day, time.hour, time.min)`, then stored in UTC. Never add days to a UTC timestamp (gotcha 14).
3. **Which dates a schedule produces** (`FamilyStudy::Recurrence`, a PORO in `app/models/family_study/`):
   - `once`: only `starts_on`.
   - `daily`: every `interval` days from `starts_on`.
   - `weekly`: every `interval` weeks on `starts_on`'s weekday.
   - `monthly`: every `interval` months, on the `week_of_month`-th weekday of `starts_on`'s weekday. A month without a fifth one is skipped; -1 is the last one (RFC 5545 `BYDAY=-1TU`).
   - Never after `ends_on` when it is set.
4. **The horizon:** sessions exist through the later of the next 31 August (end of the service year) and three months from today. A daily Solid Queue recurring task tops every repeating study up to the horizon. It is safe to run twice: it relies on the unique (`family_study_id`, `recurrence_at`) index and `insert_all`, which skips conflicts (gotcha 15).
5. **The Repeat choices come from the date.** For Tuesday 17 November 2026 (the third Tuesday):
   - Does not repeat (default)
   - Daily
   - Weekly on Tuesday
   - Monthly on the third Tuesday
   - Monthly on the last Tuesday: offered only when the date is the last Tuesday of its month

   The copy under it: "Repeating studies are planned through the end of the service year (August 31) and keep going until you end them."
6. **A cancelled session stays a row** with `canceled_at`, so the generator never recreates it. It shows as cancelled, struck through, in lists.
7. **"This session only" edits** (topic, date, time) change that row and set `detached_at`. `recurrence_at` never changes.

## Pages

All household-scoped, in the app shell (`docs/design/app-shell.md`). Primer components first; forms are Primer form classes.

| Page | Route | What's on it |
| --- | --- | --- |
| Family studies | `GET /:household_id/family_studies` | Subhead "Family studies" with "Schedule a study" (heads, adults). A BorderBox "Coming up": the next 10 sessions, each row: date · time, topic (or "Topic not chosen yet", muted), a Label for the repeat ("Weekly", "Once"). Cancelled ones struck through with "Cancelled". A Blankslate when there are none. Sidebar item "Family studies" (`book` icon) appears in this story |
| Schedule a study | `GET /:household_id/family_studies/new` | Frame `schedule-form.png`: Topic; When (Date, Starts, Ends, Repeat); Resources (add a link, drop or choose files); Notes (Lexxy); "Schedule study" and Cancel. Breadcrumbs: Family studies / New |
| Session | `GET /:household_id/family_studies/:family_study_id/sessions/:id` | Subhead: topic (or "Family study") as `h1`, description: date, time range, repeat. Notes (Lexxy, editable by heads and adults; read-only for children). Resources list with add link / add files. Actions: "Edit this session", "Cancel this session". Breadcrumbs: Family studies / date |
| Edit a session | `GET …/sessions/:id/edit` | Topic, Date, Starts. Says "Changes this session only." |
| Cancel a session | `POST …/sessions/:id/cancellation` (`Sessions::CancellationsController#create`, `#destroy` to undo) | CRUD, not a custom action (CLAUDE.md, Routing) |
| Resources | `POST/DELETE …/sessions/:session_id/resources` | Links added and resources removed from the session page |
| Files | `POST …/sessions/:session_id/files` (`Sessions::FilesController#create`) | Files the drop zone uploaded become file resources |
| Direct uploads | `POST /:household_id/direct_uploads` (`DirectUploadsController`, a subclass of Active Storage's) | Heads and adults only. Refuses a file over the limit or outside the allowlist before any bytes go up (gotcha 24) |
| A file | `GET /:household_id/resources/:id/file` (`Resources::FilesController#show`) | Authorizes, then redirects to a short-lived service URL. Never render `rails_blob_path` or `url_for(attachment)` in a page (gotcha 22) |
| Household home | `GET /:household_id` | Next family study box and "Coming up" (next 3), as in `docs/design/app-shell/desktop-light.png`. The Blankslate stays when there are no sessions |

The Schedule a study frame shows Date, Starts and Ends with friendly values. Build them with Primer's `text_field` and `type: :date` / `type: :time`: Primer passes `type` through to Rails' `text_field`, so the browser's native pickers appear. Ends is stored as `duration_minutes`; an Ends before Starts is a validation error on Ends.

## Files

- **Active Storage**, Disk service in development and test. Cloudflare R2 in production is set up in the deploy epic.
- **The drop zone is hand-built** (decided 14 Nov). Primer has no file input, so this is the one exception to "every form is a Primer form class". It's a real `<input type="file" multiple>` with a visible label, Active Storage direct upload, a Stimulus controller for drag-and-drop and progress, and BEM Sass built from Primer primitives (`components/_file_drop.scss`). Everything else on the form stays Primer.
- **Size and type are checked twice:** when the direct-upload blob is created (a `DirectUploadsController` subclass rejects anything over 25 MB or outside the allowlist, gotcha 24), and again in the model.
- **Household quota:** the sum of the household's resource blob sizes. At 80% heads and adults see a warning Banner on the session page and the form; at 100% uploads are refused with a clear message. Links don't count. Nothing is ever deleted automatically.
- **Serving:** only through `Resources::FilesController`, which authorizes before redirecting. Set `config.active_storage.service_urls_expire_in` to 5 minutes.

## Notes

- Action Text with the Lexxy editor, `has_rich_text :notes, encrypted: true`. Lexxy 1.0.4: the `lexxy` gem and the `@37signals/lexxy` npm package, pinned to the same exact version (like Primer). On Rails 8.1 installing the gem is enough for `rich_text_area` to render Lexxy instead of Trix; import `@37signals/lexxy` and `@rails/activestorage` in `app/javascript/application.js`, and load Lexxy's stylesheet from `node_modules` in `application.scss`.
- **The notes editor is the second hand-built form piece** (decided 14 Nov): Primer forms have no rich-text input. Render `rich_text_area` (Lexxy) with a visible `<label>` in Primer's `FormControl` markup, inside the same form as the Primer inputs. No custom editor styling beyond fitting Lexxy to Primer primitives. Encryption needs Active Record encryption keys: credentials in development and production, and fixed test keys in `config/environments/test.rb` so CI works without credentials.
- Rich text is user input: render it only through Action Text, never `html_safe`.

## AI helper (AI-01, decided 15 Nov)

Built in the **AI-01** epic, on the shared rules in `docs/design/ai.md` (read that first). A head or adult describes a study; the AI searches only jw.org and wol.jw.org and drafts an outline with scriptures, discussion questions and links to the pages it used. Nothing goes into the study until the person chooses "Use this draft", and nothing is saved until they choose "Schedule study".

### The panel

"Plan it with AI" sits beside the Schedule form for heads and adults (frame `schedule-form-with-ai.png`). On a phone it opens as a full-screen dialog (frame `phone-ai-draft.png`). Its states, each with a frame in `docs/design/family-studies/`:

| State | Frame | What it shows |
| --- | --- | --- |
| Start | `schedule-form-with-ai.png` | What the helper does, that it searches only jw.org and wol.jw.org, and "Draft with AI" |
| First use | `ai-terms.png` | "Before you use AI": what's sent, where it looks, what it does, check its work, the daily limit. "I understand how AI drafts work" and "Turn on AI drafts" (`docs/design/ai.md`, `Ai::Acceptance`) |
| Describe | `ai-describe.png` | "What should the study be about?" (required, 500 characters at most), three starter chips that fill the box, Length (30, 45 or 60 minutes), "Keep it easy for young children to follow", the privacy note, "Draft outline", and "8 of 10 drafts left today for the Rivera household" |
| Drafting | `ai-searching.png` | Progress lines ("Searched jw.org and wol.jw.org · 3 pages found", "Writing the outline…"), the outline streaming in, and Stop |
| Draft | `ai-draft.png` | The outline, the pages it found (title and host only, as links), the "AI can get things wrong" warning, "Use this draft", "Try again" and "Discard" |
| Added | `ai-draft-added.png` | "Draft added", with the topic, notes and links now in the form |
| Limit reached | `ai-limit.png` | "You've used today's 10 drafts", when it resets, and that the form still works. The prompt is disabled |
| Off topic | `ai-refused.png` | What they asked, and "This helper only plans family studies" with an example of what to ask |

If the provider fails, the panel goes back to Describe with their text kept and a Banner: "Couldn't make a draft right now. Try again in a moment." That attempt doesn't count. If the search finds nothing, the draft has scriptures and questions with the line "No matching pages found on jw.org or wol.jw.org."

### `FamilyStudy::Draft`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null | The limit is per household |
| `user_id` | uuid | FK → users, not null | Who asked; only they see it |
| `chat_id` | uuid | FK → chats, not null, unique | The conversation (`docs/design/ai.md`) |
| `prompt` | text | not null, encrypted | What they typed |
| `length_minutes` | integer | not null, check in (30, 45, 60) | |
| `young_children` | boolean | not null, default false | An input to the AI, not state |
| `status` | string | not null, check in (`drafting`, `drafted`, `off_topic`, `flagged`, `failed`, `stopped`) | Where the request got to |
| `outline` | jsonb | encrypted, nullable until drafted | The reply's fields, after the checks in `docs/design/ai.md` |
| `sources` | jsonb | not null, default `[]` | `[{url, title}]` that passed `Ai::SourceLink` |

- `household.family_study_drafts.counted_today` counts `drafting`, `drafted`, `off_topic` and `stopped` drafts created since midnight in the household's time zone. `failed` and `flagged` don't count.
- The reply schema: `off_topic` (boolean), `title`, `opening` (`scripture`, `question`), `points` (2 to 4, each `heading`, `scripture`, `question`), `children` (one activity, only when `young_children`), `closing`. All strings, each 300 characters at most.
- `draft.write_later` enqueues `FamilyStudy::WriteDraftJob`, which calls `draft.write_now`: moderation, then `chat.ask_within_purpose` streaming into the panel, then the checks, then `drafted` (or `off_topic`, `flagged`, `failed`). Stop sets `stopped`; the job checks between chunks and ends.
- `draft.notes_html` builds the Notes from our own ERB partial with escaped fields. Scripture references go in as plain text, and `link_scriptures` turns them into scripture links when the study is saved (`docs/design/scripture-links.md`).

### Routes

| What | Route | Notes |
| --- | --- | --- |
| Start a draft | `POST /:household_id/family_studies/drafts` (`FamilyStudies::DraftsController#create`) | Checks the person accepted the AI terms, the policy and the limit inside the household lock, then creates the draft and its chat and calls `write_later`. Responds with a Turbo Stream that shows the Drafting state |
| The panel for a draft | `GET /:household_id/family_studies/drafts/:id` | Found through `Current.user.family_study_drafts` in `Current.household`, so someone else's draft is a 404. For a reload while drafting |
| Stop or discard | `DELETE /:household_id/family_studies/drafts/:id` | Drafting: sets `stopped`. Otherwise: destroys the draft and its chat. Shows the Describe state |
| Accept the AI terms | `POST /ai_acceptance` | `docs/design/ai.md` |

"Try again" is a new `create` with the same text, so it uses one of the day's drafts. "Change" on the draft goes back to Describe with the text kept.

### Use this draft

Nothing is sent to the server. A Stimulus controller, `ai-draft`, copies from the panel into the form:

- the draft's title into Topic (only if Topic is empty; otherwise it asks "Replace the topic?" with Primer buttons)
- `notes_html`, from a `<template>` in the panel, into the Lexxy editor (appending if Notes already has text)
- each source URL into the Resources list, through the `resource-links` controller's `add`, so the form submits them as `link_urls[]`

A Primer `Label` "From an AI draft" sits beside the Notes heading until the person edits Notes. The study saves like any other; nothing records that AI was used.

### Who can do what

| | Head | Adult | Child |
| --- | --- | --- | --- |
| See the panel and draft | yes | yes | no |
| Use a draft | yes | yes | no |

`FamilyStudies::DraftPolicy`: `create?` is `FamilyStudyPolicy#create?` (heads and adults). `show?` and `destroy?` also require the draft to be the person's own.

## States each story checks

- Role: head, adult, child (children see no Schedule, Edit, Cancel or upload controls, and the controllers refuse them)
- No studies yet; one one-off study; a weekly study with many sessions
- A session with no topic; a long topic; a cancelled session
- Notes empty and filled; resources none, links, files, both
- Quota under 80%, over 80%, full
- Desktop and phone; light and dark
