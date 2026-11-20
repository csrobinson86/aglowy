# Study guide for heads and adults

Each week, a head or adult who turns it on gets their own study guide for both meetings, ready early on Monday. It does what Casey has been asking Claude for by hand: a summary of each part, what the week teaches about Jehovah, the Bible reading (what happens, what it teaches about Jehovah, how to apply it), ideas for Spiritual Gems comments, and notes for the Bible Study and the Watchtower Study. Next to each part sits the children's Get ready card for it, so a parent reviewing the week sees what the children will see.

Read this before touching `User::WeeklyStudyGuide`, `StudyGuide`, `StudyGuide::Part`, `Ai::Purpose::StudyGuide`, `StudyGuidesController`, `StudyGuides::*`, or the Study guide section of Settings. Stories live under the **PREP-02** epic. Mockup frames are in `docs/design/study-guide/`, and in the "Study guide for heads and adults (proposal)" row on the design canvas.

This builds on:
- `docs/design/meeting-prep.md`: Get ready, whose cards the guide shows, and the weekly job's rules (filling in missing parts, the word checks).
- `docs/design/daily-brief.md`: a personal AI writing made by a job in the person's time zone, Keep in Notes and Print.
- `docs/design/ai.md`: every rule there applies. Aglowy never fetches jw.org or wol.jw.org itself.
- `docs/design/settings.md`: the "You" group.

## Decisions (Casey, 20 Nov)

- **It's the summary Casey asks Claude for each week,** inside Aglowy: every part of the program, what it teaches about Jehovah, the Bible reading, ideas for Spiritual Gems comments and notes for the Bible Study.
- **Both meetings.** The weekend adds the Watchtower Study.
- **Each adult has their own,** private like their meeting notes.
- **The children's part is their Get ready card.** Each part shows the Get ready card for it, instead of writing a second children's section.

What follows from these, and needs Casey's OK in the PR:

- **Called "Study guide"**, so it isn't confused with Get ready, the children's cards.
- **Turned on per person,** in Settings → You → Study guide. It's off by default, for heads and adults only, and needs the person's accepted AI terms.
- **Read, not edited.** The guide is the AI's own words with links, like the daily brief. "Keep in Notes" makes a note the person can change, and Print prints it.
- **The program's wording isn't copied.** The guide gives references, part titles and links, and says everything else in its own words (`docs/design/ai.md`, safety measure 5).
- **Its own look, matching Aglowy.** Casey's PDF layout can be matched later if he shares it (Later).
- **Kept for 8 weeks,** then deleted. Notes made from it are kept.

## What PREP-02 builds, and what comes later

| In PREP-02 | Later |
| --- | --- |
| The Study guide setting | Matching the layout of Casey's own PDF |
| The weekly job and its AI purpose | A shared family version, read together |
| The guide: both meetings, each part, with sources and scriptures | The Public Talk (its title isn't in the program) |
| The children's Get ready cards beside each part | Other languages |
| Keep in Notes and Print | A notification when it's ready |

## Who can do what

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| Turn their study guide on or off | yes | yes | no |
| Read their own study guide, Keep in Notes, Print | yes | yes | no |
| Read someone else's study guide | no | no | no |

- The setting shows for a person who is a head or an adult in at least one active household. The guide belongs to the person (`User`), so it follows them between households.
- Its pages live under `/:household_id` like every page, and need the person to be a head or adult in that household. A child membership there gets a 404, even when the same person is an adult in another household.
- The Get ready cards beside each part come from the household in the URL, and show only while Get ready is on there (`household.meeting_prep?`).

## How it looks

| Frame | What it shows |
| --- | --- |
| `desktop-guide-midweek.png` | "Study guide" as the `h1` with a "Private" label, "Week of November 16–22, 2026 · Lamentations 1–2 · Only you see this.", a Midweek / Weekend switch (links, `aria-current`) and "My meeting notes". The AI note ("AI wrote this from this week's program on jw.org, in its own words, with links. Check each point against its page."). Then "This week at a glance"; "What this week's program teaches us about Jehovah", a list of qualities, each with a point and its reference; and a card per part. Under the cards, Keep in Notes and Print. Beside them, "Pages used" (each page the AI used, title and host) and "Scriptures in this guide" |
| `desktop-guide-weekend.png` | The weekend: the glance, the Jehovah box and the Watchtower Study card |
| `phone-guide.png` | The same page at phone width: the side column moves under the cards |
| `phone-guide-settings.png` | Settings → You → Study guide: "Make me a study guide each week", its caption, and Save |

**A part's card** has the part's name and length in small print with its tone dot (`MeetingNote::HelperSteps` tones), its title as an `h2`, a short summary, then labelled rows of points. Each point can end with a scripture link: its `ref` was parsed with `Bible::Reference.parse` when saved, and the page renders that reference as a scripture link, a whole chapter ("Psalm 23") as well as verses. `Bible::Linker` isn't used here; its verse-only rule stays for text people type. The rows depend on the part:

| Part | Rows |
| --- | --- |
| Treasures From God's Word | Main points; About Jehovah |
| Spiritual Gems | Comment ideas (2 to 4, each with its verse) |
| Bible Reading | What happens; What it teaches about Jehovah; How we can apply it |
| Apply Yourself to the Field Ministry | How we can apply it |
| Living as Christians | How we can apply it |
| Congregation Bible Study, Watchtower Study | Notes (by paragraphs, "¶4–7: …"); About Jehovah; Comment ideas (by paragraph) |

**The children's card** sits at the bottom of a part's card when the household has a Get ready card for that step: "For Eli · from Get ready" (the first names of the children using the helper), the card's `about`, its quality's words, "I can" and its `i_can`, and Change (to Get ready's Change a card, `docs/design/meeting-prep.md`). It's read-only here and drawn with a dashed border, so it reads as the children's and not the guide's.

The page uses Primer components and utilities. The few app-specific styles (the quality list, the children's card, the print styles) are BEM classes in `components/_study_guide.scss`, from primitives only.

**States:**
- Not made yet this week: "Your study guide is made early on Monday. This week's isn't ready yet." Last week's is linked, if there is one.
- Some parts missing: the parts it has, and "Some parts aren't ready yet. They'll be added when they are." Later runs fill them in (below).
- AI terms not accepted: the first-use notice from `ai.md`, with nothing made until they're accepted.

## The Settings section

- **Settings → You → Study guide** (`Settings::StudyGuidesController#show` and `#update`), after Daily brief's place in the nav. It shows for a person who is a head or adult in at least one active household.
- A Primer form (`Settings::StudyGuideForm`) with one check box, "Make me a study guide each week", the caption in the frame, and Save.
- Without accepted AI terms, the check box is disabled, with a line linking to where they're accepted.
- Turning it on prepares this week straight away (`prepare_study_guide_later`, enqueued after the switch's commit).

## The weekly job

`StudyGuide::PrepareJob` follows Get ready's job (`docs/design/meeting-prep.md`, The weekly AI job) with these differences:

- **Whose clock:** the person's (`User#limit_time_zone`, as personal study and the daily brief use). It runs hourly at minute 15 (UTC) and takes the people with the setting on for whom it's now 3am (`User.at_local_hour(3)`, added alongside `Household.at_local_hour`). So it starts within their 3am hour: at 3:15 in most zones, 3:45 in a half-hour zone such as UTC+05:30. **4am is a target, not a promise.** With the 5-minute request timeout the guide is normally there before 4am, but a failed or slow request, or a busy queue, can leave it missing until the next day's run; the page says "This week's isn't ready yet" meanwhile.
- **Only heads and adults.** The run takes only people with an active head or adult membership somewhere. Someone who loses their last one keeps the setting, but the job skips them and the Settings section is hidden. If they become a head or adult again, it resumes from the next run, as they left it.
- **The week** is the Monday of the person's current week. The program is the same everywhere, so no household's meeting times are needed.
- **Retries** run in the same 3am-hour run each day for a week still missing parts, until the week ends (Sunday night in the person's time zone).
- **Filling in, never replacing,** as Get ready does: a run asks only for the missing parts, and saves a part only where there's none. The unique (`study_guide_id`, `step`) index stops a second one.
- **The claim** is a `StudyGuide::Preparation` (`user_id`, `week_of`, unique; `token`; `created_at`), with the same token, 15-minute takeover and 5-minute timeout rules, taken under the person's lock (`user.with_lock`).
- **The owner** is the person. Without accepted AI terms nothing is asked (`:not_allowed`, no chat).
- `user.prepare_study_guide(week_of)` makes a chat (`purpose: "study_guide"`, the person as `user`, no household) and calls `Chat#ask_within_purpose` with the week's dates, `MeetingNote.program_url(week_of)` as text, and the missing steps.

### `Ai::Purpose::StudyGuide`

Instructions in `config/ai/study_guide.md`:

- `allowed_hosts`: the usual three. `max_searches`: 8 (the program, the reading, the Bible Study chapter and the Watchtower study article).
- `schema`: `off_topic`, and `parts`, a list of `{ step, content }`, where `step` is one of the steps asked for and `content` has the step's fields:

| Step | Fields (each list item is `{ text, ref }`, `ref` optional) |
| --- | --- |
| `midweek_overview`, `weekend_overview` | `glance` (at most 40 words); `jehovah`, 1 to 4 items of `{ quality (at most 3 words), text, ref }` |
| `talk` | `title`, `summary`, `points` (up to 4), `jehovah` (up to 2) |
| `spiritual_gems` | `summary`, `comments` (2 to 4) |
| `bible_reading` | `reading`, `summary`, `happens` (up to 4), `teaches` (up to 3), `apply` (up to 3) |
| `field_ministry`, `living` | `title`, `summary`, `apply` (up to 3) |
| `congregation_bible_study`, `watchtower_study` | `title`, `summary`, `notes` (up to 8, each with `paragraphs` like "4–7"), `jehovah` (up to 2), `comments` (up to 4, each with `paragraph`) |

  A `title` is the part's title as the program gives it, at most 12 words. A `summary` is at most 50 words; each item's `text` at most 30.
- **The instructions say:** find the week's program and each part's material; write for adults preparing for the meetings, in its own words, never quoting a page or a verse; give each point's scripture as a reference; make "About Jehovah" points about a quality the material really shows; make comment ideas short, in the first person, things a person could say; base notes on what the paragraphs cover, in order; return fewer parts rather than guess.
- `daily_limit`: 2 a day per person. `keep_for`: 7 days (the chat; the guide has its own rule).
- **Every safety measure in `docs/design/ai.md` applies.** Moderation is skipped because no person's text is sent. The copy check runs on every text field: a removed item goes; a part left without its `summary` (or a Bible Reading part without its `reading`, or an overview without its `glance`) is dropped, so that step stays missing for the next run. A reference that doesn't parse is dropped and its point kept. Every field is escaped when shown.
- **Checks before saving:** each step at most once, only a step that was asked for and still has none; every `summary`, `glance` and Bible Reading `reading` present and at least 1 word; the word limits, counted as `text.split.size`; list lengths; Spiritual Gems with fewer than 2 comment ideas is dropped. A run with no new parts saves nothing and lets the claim go.
- **Sources:** each source that passes `Ai::SourceLink` is kept as a `StudyGuide::Source`, title and URL only.

## Models

### `User::WeeklyStudyGuide`

The setting, as a record: it exists while the person's study guide is on.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null, cascade, **unique** | One per person |
| `created_at`, `updated_at` | datetime | | When it was turned on |

`user.study_guide_on?`, `user.turn_on_study_guide` (`create_or_find_by!`; returns false without accepted AI terms), `user.turn_off_study_guide`.

### `StudyGuide`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null, cascade | Personal; follows the person |
| `week_of` | date | not null; unique with `user_id` | The Monday |
| `chat_id` | uuid | FK → chats, nullable, nullify | Purged after 7 days |
| `created_at`, `updated_at` | datetime | | |

- `StudyGuide::PurgeJob` deletes guides more than 8 weeks old, daily at 4:55am.
- `user.study_guide_for(week_of)` reads it with its parts and sources. `study_guide.parts_for(meeting)` lists a meeting's parts in step order, its overview first.

### `StudyGuide::Part`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `study_guide_id` | uuid | FK, not null, cascade | |
| `step` | string | not null, check in the nine steps; unique with `study_guide_id` | |
| `content` | text | not null, encrypted; JSON (`serialize :content, coder: JSON`) | The step's fields, checked by the model against the step's shape |
| `created_at` | datetime | | |

- `meeting` is derived from `step` (`watchtower_study` and `weekend_overview` are weekend).
- The content is encrypted, like every personal record, so its limits are checked in the model only.

### `StudyGuide::Source` and `StudyGuide::Preparation`

As `PrepWeek::Source` and `PrepWeek::Preparation`, with `study_guide_id` and `user_id` respectively.

## Pages and routes

```ruby
resources :study_guides, only: %i[ index show ], param: :week_of do   # :week_of is the Monday, 2026-11-16
  scope module: :study_guides do
    resource :note, only: :create                                     # Keep in Notes
  end
end
```

| Page | Route | What's on it |
| --- | --- | --- |
| Study guide | `GET /:household_id/study_guides` (`StudyGuidesController#index`) | Redirects to this week's guide when there is one; otherwise the not-made-yet state, with the kept weeks listed |
| A week | `GET /:household_id/study_guides/:week_of` (`#show`, `?meeting=weekend`) | Frames `desktop-guide-midweek.png`, `desktop-guide-weekend.png`, `phone-guide.png`. Another person's week, or a week the person has none for, is a 404 |
| Keep in Notes | `POST …/study_guides/:week_of/note` (`StudyGuides::NotesController#create`) | Makes a `PersonalNote` titled "Study guide · Week of November 16", from our own partial: every field escaped, every `ref` attached as a scripture link from its parsed reference (whole chapters too, as on the page). The children's cards aren't included. Then the note's read view |
| Settings | `GET`/`PATCH /:household_id/settings/study_guide` (`Settings::StudyGuidesController`) | Frame `phone-guide-settings.png` |

- **Print** is the daily brief's `print` Stimulus controller and print styles that omit the sidebar, the side column and the buttons. The children's cards print with the guide. So that a printed guide can still be checked against its sources, a "Pages used" list is printed at the end, each page's title followed by its full URL (shown only in print).
- **Where people find it**, for a head or adult with it on: the sidebar's Mine group gains "Study guide" (Octicon `book`) after Today's meeting; Home's Today's meeting card gains "Read this week's study guide"; and the meeting note edit page links to it beside the outline.
- **`StudyGuidePolicy`:** a head or adult membership in this household, and the guide's `user` is `Current.user`.

## Changes to other docs in this PR

- `docs/design/meeting-prep.md`: "A family version for heads and adults" in Later points here.
- `docs/design/ai.md`: `study_guide` joins the purposes; safety measure 8 lists the study guide with the daily brief as heads-and-adults only.
- `docs/design/settings.md`: the "You" group gains Study guide.
- `docs/product/vision.md`: roadmap row 25, PREP-02.

## Traps

1. **Never fetch the program.** Its address goes into the question as text.
2. **References and links only.** No verse text, no wording from the publications (`ai.md`, safety measure 5). Part titles are the one thing taken as the program gives them.
3. **It's the person's, not the household's.** Look it up through `Current.user.study_guides`; never show it to another member, and never put it in a household's shared views.
4. **The children's cards are the household's.** Read them through `Current.household`, only while Get ready is on there, and only for a head or adult.
5. **AI output is untrusted text.** Escape every field, in the page, the note and the print view.
6. **The person's clock, not a household's,** for the job, the week and the limit.
7. **Tests never call a provider.** The job's tests use a recorded reply in `test/fixtures/files/ai/study_guide.json`.

## States each story checks

- **The setting:** off; on; a head, an adult, a child only (no section); AI terms not accepted (disabled, with the link); turning on prepares this week
- **The job:** first run; run twice; two at once (one request); a claim taken over; AI terms not accepted (no chat); a week with every part (no request); a week missing parts (asks for those only, keeps the rest); the copy check removing a summary (the part dropped) and an item (the item dropped); a bad reference (dropped, point kept); too few comment ideas; the week over (no retry); a person behind UTC (3am their time); a person with no head or adult membership left (skipped, setting kept, resumes when they're one again)
- **The page:** a chapter-only reference linked; the printed sources list; a head and an adult with it on; a child membership (404); another person's week (404); not made yet; some parts missing; midweek and weekend; with and without Get ready on in this household; two children using the helper; desktop and phone; light and dark
- **Keep in Notes:** the note's title and body; escaped text; scripture links; no children's cards
- **Print:** the guide alone, with the children's cards
