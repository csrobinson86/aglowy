# Family studies

How a household schedules a family study, what each occurrence holds, and the pages for it. Read this before touching `FamilyStudy`, its sessions, its resources or their pages. Stories for the first build live under the **STUDIES-01** epic.

The data model was agreed in the users design ("Aglowy — Users Domain Model", planned models and gotchas 14–17 and 21–24). This document repeats what a builder needs and adds the decisions taken since. The mockup frames are in `docs/design/family-studies/`.

## What STUDIES-01 builds, and what comes later

| In STUDIES-01 | Later |
| --- | --- |
| Schedule a one-off or repeating study (daily, weekly, monthly, every N) | "All future sessions" edits that move the schedule (gotcha 16) |
| Sessions generated ahead, safe to rerun | Guests and invitations |
| Family studies list and a page per session | Reminders and notifications |
| Session notes in Lexxy, encrypted | AI study helper (see "AI helper" below) |
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
| Resources | `POST/DELETE …/sessions/:session_id/resources` | Links and files added from the session page |
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

## AI helper (later epic, decided 14 Nov)

Not part of STUDIES-01. Recorded here so the first build leaves room for it.

- **Optional.** A head or adult can always schedule a study without it. The "Plan it with AI" panel sits beside the form (frames `schedule-form-with-ai.png`, `ai-describe.png`, `ai-draft.png`, `ai-draft-added.png`, `phone-ai-draft.png`); STUDIES-01 builds the form at its narrower width with no panel.
- **Privacy first.** Before first use, a person sees a privacy notice and accepts the AI terms; the AI form stays disabled until they do. The prompt box always says what's sent and to leave out names and private details.
- **Nothing is saved until the person chooses "Use this draft"**, and the draft is labelled until edited.
- **Still to design with Casey:** moderation and limits on what the AI may do in Aglowy, how drafts draw only on jw.org and wol.jw.org (fetching real pages through RubyLLM tools and accepting only links on those hosts that load), and a check of jw.org's terms of use.

## States each story checks

- Role: head, adult, child (children see no Schedule, Edit, Cancel or upload controls, and the controllers refuse them)
- No studies yet; one one-off study; a weekly study with many sessions
- A session with no topic; a long topic; a cancelled session
- Notes empty and filled; resources none, links, files, both
- Quota under 80%, over 80%, full
- Desktop and phone; light and dark
