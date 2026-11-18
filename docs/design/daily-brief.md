# Daily brief

A short brief to start the day, ready before the person is up. Each morning a job puts it together from the person's own plan: the day's text, a Bible reading, a quality to work on, one thing to do in each of their focus areas, and a faith example to imitate, tied together by one thread. In the evening the same brief has a few questions to end the day. Stories live under the **BRIEF-01** epic.

It builds on `docs/design/ai.md` (read that first), `docs/design/meeting-parts.md` (one chat per AI request, and what happens when a request doesn't finish), `docs/design/meeting-notes.md` (sharing), `docs/design/notes.md` and `docs/design/goals.md`.

Frames in `docs/design/daily-brief/` (README there). Mockups are in the "Daily brief" row on the design canvas.

## Decisions (Casey, 17 Nov)

- **A daily brief that's there when the person signs in.** A job writes it early each morning. It replaces the scheduled job Casey runs for himself today.
- **Built around the person's focus areas.** For Casey: as a husband, as a father, reaching out to qualify as a ministerial servant, qualities to focus on, and growing appreciation for Jehovah. Each gets a short section with one thing to do that day.
- **No prayer focus.**
- **The mockups as they are, as version 1.** Making it fit other people's needs better comes after (Later, below).

What follows from these, and needs Casey's OK in the PR:

- **References and links only.** A brief gives the reference, what to look for in the AI's own words, and a link. It never holds verse text or a publication's wording (`docs/design/ai.md`, safety measure 5). Casey's own job quotes both; Aglowy's can't.
- **Heads and adults only.** A child has no daily brief in this version, with or without AI.
- **Three AI writings per person per day:** the morning's, and two more ("Another angle", or trying again after one was stopped or off topic). One that failed or was flagged isn't counted, as in the other AI features, and a brief takes six requests at most whatever their endings.
- **Kept for 60 days, shown for one.** The page shows today's brief. Earlier ones are kept 60 days only so the next briefs can avoid repeating them, then deleted. "Keep in Notes" makes a note that is the person's to keep.
- **It pauses itself after 7 briefs in a row that the person never saw,** on the brief's page or on their Home card. That takes one fact per brief: when the person first saw it. Nothing else about their use is recorded.
- **No notification when it's ready.** It's simply there. A notification kind can come later.
- **Sharing is small and quiet.** "Share with the family" shows the household the thread, the reading and the children's box, for that day, and sends no notification.
- **English only.** The Daily text link and the brief are in English.

## What BRIEF-01 builds, and what comes later

| In BRIEF-01 | Later |
| --- | --- |
| A plan: starter plans, focus areas, a week of rows, which sections are in every brief, ready-by time, pause | "Let it choose" and "one theme a week" instead of a week of rows; a length setting; sections in any order |
| The morning job, per time zone | A notification when it's ready |
| The brief from the plan alone, when there's no AI | A plan with the person's own prompts and no AI at all |
| The AI part: the thread and each section, with sources | A focus area for a season, with an end date |
| Evening questions | Reading from a Bible reading plan |
| The brief on Home; sharing the thread and the children's box with the household | A child's own brief; the children's box by age |
| Keep in Notes; print | Audio; other languages |
| A focus area linked to one of the person's goals | Copying a plan inside the household |

## Who can do what

| | Head, adult | Child |
| --- | --- | --- |
| Have a plan and a daily brief | Yes | No |
| The AI part | After accepting the AI terms (`Ai::Acceptance`) | No |
| See "Today's thought" on Home when someone shares it | Yes | Yes |

- `User#may_have_daily_brief?`: a head or adult in any active household. The brief is the person's, not one household's, and follows them (`docs/design/users.md`).
- `DailyBriefPolicy` answers every action with it. Children don't see the sidebar item, and the pages refuse them.
- A brief is never visible to anyone else. Staff don't see it; Madmin gets no resource for it.

## Data model

Everything the person types is encrypted (`docs/product/vision.md`, Private by default).

### `DailyBrief::Plan`

One per person.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK, not null, unique, `on_delete: :cascade` | |
| `ready_at_minutes` | integer | not null, default 300, check 240 to 480 in steps of 30 | "Ready by", 4:00 to 8:00 AM, in the person's zone (`User#calendar_time_zone`) |
| `sections` | string[] | not null, default all five, check within the five | Which of `daily_text`, `reading`, `faith_example`, `children`, `evening` are in every brief |
| `started_at` | datetime | not null | When the plan was started, or started again after a pause. The morning job's first brief is the morning after, and the pause rule counts unseen briefs from here |

- `has_many :focus_areas` (in `position` order), `has_many :days`, `has_one :pause`
- `Plan.start(user, starter:)` builds the plan, its seven days and its focus areas from a `DailyBrief::Starter` (a PORO): `husband_and_father`, `wife_and_mother`, `on_my_own` or `basics`.
- `Plan.start` sets `started_at`, and so does `plan.resume`.
- `plan.due?(now)` is true when all of these are:
  - it isn't paused
  - `user.today` is after the day of `started_at` in the person's zone, so a plan started or started again today gets the job's first brief tomorrow, as the Start page says
  - the person's local time is within 45 minutes of ready-by, or past it
  - today's brief isn't prepared: there's none, or it has no writing and the person has accepted the AI terms

### `DailyBrief::FocusArea`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `plan_id` | uuid | FK, not null, `on_delete: :cascade` | |
| `position` | integer | not null | The order on the plan and in the brief |
| `kind` | string | not null, check in (`role`, `quality`, `appreciation`) | How its section is laid out (The brief, below) |
| `name` | string | not null, encrypted, 60 characters at most | "As a husband" |
| `gives` | text | not null, encrypted, 200 at most | What the person wants from it each day |
| `scriptures` | string | nullable, 120 at most | References, each of which must parse (`Bible::Reference.parse`); shown as links |
| `goal_id` | uuid | FK → goals, nullable, `on_delete: :nullify` | One of the person's own goals (`Goal` with their `user_id`) |

- Six at most. One `quality` and one `appreciation` at most (partial unique indexes).
- `DailyBrief::FocusArea::Library` (a PORO) holds the ready-made ones the dialog offers: as a husband, as a father, as a wife, as a mother, reaching out, in the ministry, in the congregation, at work, guard your heart, qualities to focus on, growing appreciation for Jehovah. Picking one fills the form; the person can change every field.

### `DailyBrief::Day`

Seven per plan, made with it.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `plan_id` | uuid | FK, not null, `on_delete: :cascade` | |
| `wday` | integer | not null, 0 to 6, unique with `plan_id` | |
| `reading` | string | nullable, encrypted, 120 at most | "Matthew – John" |
| `examples` | string | nullable, encrypted, 200 at most | "Abraham, Moses" |
| `topics` | jsonb | not null, default `{}`, encrypted | The day's topic for a focus area, keyed by its id: "Serious (v. 8)". 120 characters each |

An empty box means the brief chooses. The Qualities column on the page is the `quality` focus area's topics.

### `DailyBrief::Pause`

State as a record: `plan_id` (FK, unique, `on_delete: :cascade`), `reason` (check in `chosen`, `unseen`) and `created_at`. Present means paused: nothing is written and nothing is sent. `plan.pause(reason:)` makes it under `user.with_lock`, and in the same lock stops any writing of the person's that is still `writing` (it ends `stopped` and keeps its use, as a Stop does). A writing whose job hasn't started then sends nothing, because `write_now` starts only while its writing is `writing`. One already waiting on the provider has sent its request; its ending stays `stopped`, and nothing it returns is shown. `plan.resume` deletes it and sets the plan's `started_at` to now, so the briefs that went unseen before the pause can't pause it again.

### `DailyBrief`

One day's brief.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK, not null, `on_delete: :cascade` | |
| `on` | date | not null, unique with `user_id` | The person's local date |
| `plan` | jsonb | not null, encrypted | A copy of what the brief was built from: the sections, the focus areas and that day's row. Changing the plan never changes a brief already made |
| `seen_at` | datetime | nullable | The first time the person saw it: on its page, or on their own Home card. Set once by `brief.mark_seen`; used only to pause after 7 unseen |

- `DailyBrief.for(user, on: user.today)`: inside `user.with_lock`, finds the day's brief or makes it with the copy of the plan.
- `has_many :writings`; `brief.writing` is the newest one that is `written`.
- `include Shareable` with `DailyBrief::Sharing`, and no notification (Sharing, below). `Shareable` always notifies today, so it gains a private `notifies_when_shared?`, true unless the record says otherwise, which `DailyBrief` turns off. It guards both halves: the notifications `share_with` makes and the withdrawal in `stop_sharing_with`, which reads a `notifications` association a daily brief doesn't have. So `DailyBrief` declares no notifications and isn't a notification subject, and meeting notes and goals notify and withdraw as before. `Membership#deactivate` ends the person's daily brief shares in that household, as it does for meeting notes and goals.
- `brief.daily_text_url`: `https://wol.jw.org/en/wol/dt/r1/lp-e/<year>/<month>/<day>`, built from `on`. Aglowy never fetches it.

### `DailyBrief::Writing`

One AI request and its checked reply, with a chat of its own, as a meeting part draft has (`docs/design/meeting-parts.md`, Trap 9).

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `daily_brief_id` | uuid | FK, not null, `on_delete: :cascade` | |
| `chat_id` | uuid | FK → chats, not null, unique, `on_delete: :cascade` | One request and one reply. The purge deletes the chat, and the writing goes with it |
| `status` | string | not null, check in (`writing`, `written`, `off_topic`, `flagged`, `failed`, `stopped`) | |
| `result` | jsonb | encrypted, nullable until written | The checked reply fields |
| `sources` | jsonb | not null, default `[]` | `[{url, title}]` that passed `Ai::SourceLink` |

- `belongs_to :chat, dependent: :destroy`
- `Ai::Use` gains `daily_brief_writing_id` (FK, nullable, unique, `on_delete: :nullify`), used as `question_id` is for personal study.

## The morning job

`DailyBrief::PrepareJob` runs every 15 minutes (`config/recurring.yml`). For each plan that is `due?`:

1. If `plan.gone_unseen?`, it makes a `Pause` with `reason: unseen` and stops there. That's true when the person has at least 7 briefs made since `started_at` and dated before today, and the newest 7 of those all have no `seen_at`. Today's own brief never counts, so a run that picks up a brief the last run made can't pause on it. Someone who reads the card on Home each day and never opens the page isn't paused.
2. `DailyBrief.for(user)` finds or makes the day's brief.
3. If the person has accepted the AI terms and the brief has no writing, `brief.write(by: user, first: true)` starts the AI part (How a writing runs). `first: true` checks again, inside the lock, that the brief has no writing, so two runs at once start one.

It starts 45 minutes before ready-by so the brief is there on time. Running twice is safe: the brief is unique per day, and the job starts a writing only for a brief that has none. A run that stopped between steps 2 and 3 is finished by the next one, because a brief with no writing is still due. The job never starts a second writing for a brief, whatever the first one's ending. At this size the job walks the unpaused plans and asks each one; give it a scope when there are thousands.

If the job didn't run, the page has "Prepare today's brief" (`POST /:household_id/daily_brief`), which does steps 2 and 3 whatever `due?` says, but never for a paused plan: it shows the paused page instead. A page left open from before the pause can't get round that, because `brief.write` refuses a paused plan inside the lock that `plan.pause` takes.

## Pages and routes

Under `/:household_id` in the household layout. The data is always found through `Current.user`.

```ruby
resource :daily_brief, only: %i[ show create ] do
  resource :plan, only: %i[ new create show update ], module: :daily_briefs do
    resource :pause, only: %i[ create destroy ], module: :plans
    resources :focus_areas, only: %i[ new create edit update destroy ], module: :plans
    resources :days, only: %i[ edit update ], module: :plans, param: :wday
  end
  resources :writings, only: %i[ create show destroy ], module: :daily_briefs
  resource :sharing, only: %i[ create destroy ], module: :daily_briefs
  resource :note, only: :create, module: :daily_briefs
end
```

| What | Route | Frame |
| --- | --- | --- |
| Today's brief | `GET /:household_id/daily_brief` | `brief-today.png`, `brief-dark.png`, `phone-brief.png` |
| This evening | the same, with `part=evening` | `brief-evening.png` |
| Start | `GET …/daily_brief/plan/new`, `POST …/plan` | `brief-start.png` |
| Your plan | `GET` and `PATCH …/daily_brief/plan` | `brief-plan.png` |
| Add or edit a focus area | `…/plan/focus_areas`, in a Primer `Dialog` | |
| Edit a day | `…/plan/days/:wday`, in a Primer `Dialog` | |
| Pause, start again | `POST` and `DELETE …/plan/pause` | |
| Another angle, try again | `POST …/daily_brief/writings` | |
| A writing in progress, Stop | `GET` and `DELETE …/writings/:id` | reuses `family-studies/ai-searching.png` |
| Share with the family, stop | `POST` and `DELETE …/daily_brief/sharing` | `brief-family.png` |
| Keep in Notes | `POST …/daily_brief/note` | |
| The brief without the AI part | the same `show` | `brief-base.png` |
| On Home | `dashboards#show` | `brief-home.png` |

### The sidebar

"Daily brief" is first in the Mine group (`docs/design/app-shell.md`), with the `north-star` Octicon. Heads and adults see it.

### Start

Someone with no plan lands here from the sidebar. A Blankslate-style heading, "Start from a plan" (a radio group of the four starters, each listing its focus areas), the AI notice, and "Start my daily brief". The job's first brief is ready the next morning (`started_at`, above). Someone who hasn't accepted the AI terms can still start: their brief has the parts from the plan, and the brief page offers "Turn on AI drafts" (`ai-terms.png`).

### Your plan

- **Focus areas:** a list with the name, what it gives, its scriptures and a linked goal; Edit on each; "Add a focus area" opens the dialog, and the chips open it filled in from the library.
- **Every field that's sent to the AI says so.** The focus area dialog's name and what-it-gives fields, and each box in a day's dialog, carry the caption "Sent to the AI as you type it. Leave out names."
- **Your week:** a table with a row per day and a column for Reading, each focus area that takes a topic, and Faith examples. Today's row is marked with the word "Today", not colour alone. "Edit" opens that day's dialog (`DailyBriefs::Plans::DayForm`). An empty box reads "The brief chooses".
- **In every brief:** five check boxes for the sections.
- **When:** "Ready by", with the person's time zone named.
- **What's sent to the AI,** in words (The purpose, below).
- **Save plan,** and **Pause the daily brief** or **Start it again**.

Changes apply from the next brief. Every form is a Primer form class; a refused save re-renders with `:unprocessable_content`.

### The brief

- **The header:** "Daily brief", a "Private" Label, the date, a Morning / Evening switch and "Your plan".
- **Today's thread:** one sentence that ties the day together, with the day's flow under it as links to the sections.
- **Sections,** each a bordered section with a small kicker and an `h2`:
  - **Daily text:** the reference, a link to the day's text on wol.jw.org, and three short parts: what's happening, what it teaches me about Jehovah, how I can use it today.
  - **Bible reading:** one passage from the day's books, a link to the chapter, and up to three things to look for by verse.
  - **A `quality` focus area:** what it is, how Jesus showed it, one way today.
  - **An `appreciation` focus area:** what today's reading shows about Jehovah, and a question to think over.
  - **Your focus today:** one row per `role` focus area with one thing to do and a scripture. A linked goal adds "Your goal: … · next step: …" from Aglowy's own data.
  - **Imitate their faith:** one or two examples, each with a lesson and scriptures, and a "For me" line.
- **Beside it:** "Today in Aglowy" (the person's own times, meetings and family study for today, from `Household::Calendar`, no AI), "For the children", "This evening", and "Pages it used" with the "AI can get things wrong" warning and what was sent.
- **Under it:** Keep in Notes, Print, and "Another angle" with how many are left today.
- Every scripture is a link made by `Bible::Reference` (`docs/design/scripture-links.md`), never by the AI.

States:

| State | What the page shows |
| --- | --- |
| No plan | Start |
| Paused | A Blankslate: "Your daily brief is paused", why (you paused it, or you hadn't looked at seven in a row), and "Start it again" |
| Before the first brief | "Your first brief is ready tomorrow morning", and "Prepare today's brief" for someone who wants one now |
| Today's isn't made yet | Yesterday's brief with its date, and "Today's brief is ready by 5:00 AM". After ready-by with none made: "Prepare today's brief" |
| Made, with no writing yet, AI terms accepted | The parts from the plan and "Write it with AI" (`writings#create`). The next run of the morning job starts it too |
| Being written | The parts from the plan, and the AI's progress lines with Stop |
| Written | The whole brief |
| No AI terms | The parts from the plan, and "Turn on AI drafts" |
| Failed, flagged, off topic, stopped | The parts from the plan and a Banner saying so; "Try again" while requests are left (`brief-base.png`) |
| Limit reached (3 counted today, or 6 writings of this brief) | "Another angle", "Try again" and "Write it with AI" are replaced by "No more today" |

The parts from the plan are: the Daily text link, the day's reading books, the day's qualities and examples, and each focus area's name, topic and scriptures.

### This evening

The Evening switch shows "Four questions to end the day" above a short list of what the morning held. The questions come from the same writing as the morning. They open at 6:00 PM in the person's zone; before that the place says so. There are no inputs: Aglowy doesn't ask for answers and saves nothing. "Write a note about today" opens a new note (`docs/design/notes.md`) with the date as its title: `personal_notes#new` takes an optional `title` for this, and nothing is saved until the person saves the note.

### For the children, and sharing

When `children` is among the plan's sections, the brief has a question to ask the children and one thing to do today. Nothing about the children is sent: the AI writes for "the children", with no names or ages.

"Share with the family" makes a `DailyBrief::Sharing` for `Current.household`. Other members then see a "Today's thought" card on Home: the thread, the reading as a link, and the children's box, with "Shared by Daniel". Nothing else in the brief is shown to anyone, ever. The card shows on the brief's day only. There is no `shared_with_you` notification: a share every morning would nag (`docs/product/vision.md`, goal 4).

### On Home

For the person: a "Your daily brief" card at the top of Home, with "Only you see this", the thread, the reading, the quality and the example, and "Open today's brief". Without a written brief it shows what the plan gives. No card when there's no plan or it's paused. Showing the card counts as seeing the brief (`brief.mark_seen`).

### Keep in Notes, and print

- **Keep in Notes** makes a `PersonalNote` titled "Daily brief · Tuesday, November 17". Its body comes from our own ERB partial with every field escaped and every reference a scripture link, as a family study draft's notes do. The note is the person's and is never purged.
- **Print** is a `print` Stimulus controller calling `window.print()`, and print styles in `components/_daily_brief.scss` (BEM, from primitives) that leave out the sidebar, the side column and the buttons.

## The AI part

Everything in `docs/design/ai.md` applies. This section only adds to it.

### The purpose: `Ai::Purpose::DailyBrief`

- **Its one job:** write a daily brief from a plan of spiritual focus areas. Anything else is `off_topic`.
- `instructions` in `config/ai/daily_brief.md`; `allowed_hosts` as always; `max_searches` 6
- `daily_limit` 3 per person, counted from `Ai::Use` rows since midnight in `User#limit_time_zone` under the person's lock, as personal study counts its questions
- `keep_for` 60 days. Each writing has its own chat, so the daily purge (`Ai::PurgeExpiredChatsJob`) deletes a chat 60 days after it was made and the writing goes with it. `DailyBrief::PurgeJob`, daily, deletes briefs more than 60 days old with their writings and chats. `daily_brief` joins the `chats` and `ai_uses` purpose checks.
- **What's sent:** the date; which sections are on; each focus area's name, what it gives and its scriptures; the day's row (reading, examples, topics); and the passages, qualities and examples used on this weekday in the person's last 8 briefs, as references and the names of the qualities and Bible examples only, to avoid repeating them. **Aglowy adds nothing else:** never the person's name, their family's names, their notes, a goal's wording or the household (`docs/design/ai.md`, safety measure 7). The plan page says so.
- **What the person typed in the plan is sent as typed,** as a family study request or a personal study question is. Aglowy doesn't try to find and remove names in it. No filter does that reliably, and one that removed the household's own names would also remove qualities: Grace, Faith, Joy and Patience are names too. The control is where the text is typed: every field that's sent says so and asks for no names (Your plan), the plan page lists what's sent, and nothing is sent at all until the person has accepted the AI terms.
- **Moderation** runs on everything the person typed that is sent, together.

### The reply

One schema. A section that is off in the plan is left empty and ignored.

- `off_topic` (boolean)
- `thread`: one sentence, 200 characters at most
- `daily_text`: `reference`, `happening`, `teaches`, `apply`, `apply_scripture`
- `reading`: `passage` (a reference), `title`, `look_for` (1 to 3, each with `verses` and `text`)
- `quality`: `name`, `what`, `what_scripture`, `jesus`, `jesus_scripture`, `today`
- `appreciation`: `title`, `seen`, `scripture`, `think`
- `focus`: one per `role` focus area, in the plan's order, each with `action` and `scripture`
- `faith`: `examples` (1 or 2, each with `name`, `lesson`, `scriptures`) and `for_me`
- `children`: `ask` and `today`
- `evening`: 3 or 4 questions, each with `text` and `from` (the section it looks back on)
- Every string is 300 characters at most.

The checks, in order:

1. Off topic ends `off_topic`.
2. `Ai::CopyCheck` on every text field and `Ai::SourceLink` on the sources.
3. Every reference field goes through `Bible::Reference.parse`. One that doesn't parse is dropped and the rest of its section stays.
4. **The daily text is kept only when its page is among the sources.** The AI's `daily_text` is shown only if a source that passed `Ai::SourceLink` is that day's `daily_text_url`. Otherwise the section shows the link alone. Aglowy can't check the text itself, so it checks that the AI read the right page.
5. **Minimum:** the thread and two sections. Less ends `failed`, and its use is deleted.

### How a writing runs

`brief.write(by: user)` does this inside `user.with_lock`:

- refuses with `:limit` when 3 of the person's `daily_brief` uses are from today, or when this brief already has 6 writings whatever their endings
- refuses with `:not_allowed` unless `may_have_daily_brief?` and `accepted_ai_terms?`
- refuses with `:paused` while the plan is paused
- with `first: true` (the morning job, "Prepare today's brief" and "Write it with AI"), refuses with `:written` when the brief already has a writing of any status. "Another angle" and "Try again" don't pass it
- refuses with `:busy` while a writing of this brief is `writing`
- makes the writing (`writing`) with its own chat and its `Ai::Use`

After the lock block returns it calls `write_later`. `DailyBrief::WriteJob` → `writing.write_now`, the same five steps as `FamilyStudy::Draft#write_now`: moderation; `chat.ask_within_purpose` with progress lines only; the checks; the final status with a conditional update that applies only while `writing`; one broadcast of the result.

What counts, a refused job, a job that raises, Stop, and the accepted gap are exactly as in `docs/design/meeting-parts.md`, When a request doesn't finish: `failed` and `flagged` delete the use, every other status keeps it, and whichever ending is written first stands.

So the 3 a day are the requests that didn't end in a failure. Because a failed one gives its use back, a plan whose replies keep failing the checks could otherwise be tried again without end, and each try is a paid request. The cap of 6 writings per brief stops that: it counts every writing, failed or not.

"Another angle" is a new writing of the same brief. The page shows the newest written one; the earlier one stays until the purge and isn't shown.

## Elsewhere

- **`docs/design/ai.md`:** the `daily_brief` purpose, its limit and `keep_for`; safety measure 8 notes that the daily brief is for heads and adults only.
- **`docs/design/app-shell.md`:** the Mine group starts with Daily brief. Home's two cards are specified here (On Home; For the children, and sharing).
- **`docs/product/vision.md`:** roadmap row 20, BRIEF-01.
- **Seeds** (`db/seeds/`): a plan from the husband-and-father starter for a seeded adult, today's brief with a written writing from a saved reply (never a provider call), shared with the household; a second adult with a plan and no AI terms.

## Traps

1. **No verse or publication text.** References, links and the AI's own words. The limits of the checks are the ones in `docs/design/meeting-parts.md`, Trap 4.
2. **Send only the plan's own words and the date.** Aglowy adds no names, no goal's title or steps and no notes, even though the brief page shows a goal's next step beside the AI's text. The plan's words go as the person typed them: don't add a name filter (The purpose says why), and keep the "Leave out names" caption on every field that's sent.
3. **Never show a daily text the AI didn't read.** Check 4 decides, not the reply.
4. **The evening questions have no inputs.** Don't add check boxes, a score or a history.
5. **One fact about use.** `seen_at` is set once, by the brief's page or the person's own Home card, and read only by the pause rule. A shared thought on someone else's Home never sets it. No streaks, no counts, no "you missed yesterday".
6. **One brief a day, one writing at a time, one chat per writing.** `DailyBrief.for` and `brief.write` run under the person's lock; the job is safe to run twice, and it finishes a brief it made but didn't start writing.
7. **A brief is a copy.** It reads its own `plan`, never the live plan, so editing the plan can't change or break today's brief.
8. **Sharing shows three things:** the thread, the reading and the children's box. The shared card is found through `DailyBrief.shared_with(Current.household)`, on its day only.
9. **Don't show a writing's text while it's being written,** and don't let a finished job override Stop (`docs/design/ai.md`, Traps).
10. **Children have no daily brief.** No sidebar item, and the policy refuses every action. Don't add a grant or a setting.
11. **AI output is untrusted text.** Escape every field. The note body is built by our partial, never from AI HTML.
12. **Paused means nothing is sent.** `plan.pause` stops a running writing in the person's lock, and `brief.write` refuses a paused plan in the same lock, so neither the job, a stale page nor a queued job sends after a pause.
13. **`started_at` is where the job and the pause rule begin.** The job's first brief is the morning after it, and only briefs made since it, and dated before today, count toward seven unseen. Set it on start and on every resume, or a plan started again after seven unseen pauses itself the next morning.
14. **Failures are free to the person, not to us.** A failed or flagged writing gives its use back, so the 6 per brief is the only thing between a plan that keeps failing and endless paid requests. Count every writing for it.

## States each story checks

- Person: head, adult, child (no brief), a member seeing a shared thought, a non-member (404), not yet accepted the AI terms
- Plan: none, each starter, six focus areas, a focus area with and without scriptures and a goal, a day with every box empty, each section off, paused by choice, paused after seven unseen, started again (not paused again the next morning), started today (no brief from the job until tomorrow)
- Brief: none yet, yesterday's before ready-by, made by the job, made from the page, made by the job with no writing (the next run starts one, even when it's the seventh unseen), built from an edited plan (unchanged)
- AI: written, a section off, off topic, flagged, provider error, the daily text's page missing from the sources (link only), a reference that doesn't parse (dropped), a quotation of more than 5 words (removed), too thin, stopped, 2 used and 3 used, 6 writings of one brief, a new day in the person's time zone
- Evening: before and after 6:00 PM in the person's zone
- Sharing: shared, stopped, the day after, another household
- Kept: a writing 61 days old goes with its chat; a brief 61 days old goes; a note kept from a brief stays
- Light and dark, desktop and phone, `assert_accessible` on every page
