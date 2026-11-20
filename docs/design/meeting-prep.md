# Get ready for the meetings, for children

A child using the meeting helper gets a few simple cards before each week's meetings, to read with a parent. There's one card for each part, saying what the part is about, something it shows about Jehovah, and one thing she can do this week. The Bible Reading card tells the reading as a short story she can draw. For the Congregation Bible Study and the Watchtower Study, she gets her own comment ready, in her own words. A weekly AI job writes the cards, the way it finds the listening game's cards.

Read this before touching `Household::MeetingPrep`, `PrepWeek`, `PrepWeek::Card`, `Ai::Purpose::MeetingPrep`, `MeetingPrepsController`, `MeetingPreps::*`, or the Get ready check box in Settings → Children. Stories live under the **PREP-01** epic. Mockup frames are in `docs/design/meeting-prep/`, and in the "Get ready for the meetings, for children (proposal)" row on the design canvas.

This builds on these docs:
- `docs/design/meeting-helper.md`: the helper, its steps, its layout, drawing, "Show my family".
- `docs/design/listening-game.md`: the weekly AI job (claims, owner, AI terms, sources), and `MeetingNote::Answer`, her own answer.
- `docs/design/ai.md`: every rule there applies. In particular, Aglowy never fetches jw.org or wol.jw.org itself.
- `docs/design/settings.md`: the Children section.

## Decisions (Casey, 20 Nov)

- **Separate from the meeting helper, and just for her.** Get ready is something she does before the meeting, small and focused, so she understands what the meeting will talk about and how it applies to her. The helper stays what she uses during the meeting.
- **Both meetings,** midweek and weekend.
- **She sees the cards as soon as they're made.** A parent doesn't have to check them first.
- **Parents turn it on and off in Settings,** in the Children section, under the meeting helper.
- **Her comment is one she makes up.** The AI doesn't suggest comments or questions. She picks a paragraph with her family and says it her own way.

What follows from these, and needs Casey's OK in the PR:

- **A card says three things,** in child words: what the part is about, one quality of Jehovah the part shows (from a fixed list of ten, each with its own icon), and one thing she can do this week. The Bible Reading card adds the story in up to four short sentences, and Draw it!.
- **Five parts get cards:** Treasures From God's Word, the Bible Reading, Living as Christians and the Congregation Bible Study on the midweek meeting, and the Watchtower Study on the weekend. The Public Talk has none, because its title differs from one congregation to the next and the program doesn't say it. Spiritual Gems and the field ministry parts have none either, so the set stays small (Later, below).
- **Parents can read and change every card,** on their own page, the way they change listening game rounds. Changing a card doesn't stop her seeing it in the meantime.
- **It needs the meeting helper.** The check box shows only while the helper is on, and turning the helper off turns Get ready off too. Her pages use the helper's layout, so the cards are big, dark and calm, like the rest of what she uses.
- **Nothing that nags.** No sounds, no animation, no points, no "done" marks to collect. She can look at the cards as often as she likes.
- **Gentle words.** The AI is told to write for a 4-to-8-year-old and to say hard things gently, with no frightening details.

## What PREP-01 builds, and what comes later

| In PREP-01 | Later |
| --- | --- |
| The Get ready check box in Settings → Children | Cards for Spiritual Gems, the field ministry parts and the Public Talk |
| The weekly AI job and its purpose | Reading a card aloud with the device's own voice |
| Her Get ready page: the week's two meetings, one card at a time | Cards in other languages |
| Her comment for the Congregation Bible Study (the listening game's answer) and the Watchtower Study (new) | A family version for heads and adults: the study guide, `docs/design/study-guide.md` (PREP-02) |
| Draw it! from the Bible Reading card | "I can…" coming back in "Talk about it" after the meeting |
| The parent's page, and Change | Picture cards (Aglowy can't use jw.org's artwork) |

## Who can do what

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| Turn Get ready on or off | yes | yes | no |
| Read this week's cards on the parent's page, and change one | yes | yes | no |
| Her Get ready pages, her comment, Draw it! | no | no | yes, while the helper and Get ready are on |

- Her pages are **for children only, while both the helper and Get ready are on**. Anyone else gets a 404 there, like the helper's own pages.
- The parent's page is for heads and adults while Get ready is on (`HouseholdPolicy#manage_meetings?` and `household.meeting_prep?`). Anyone else gets a 404.
- Her comment and drawing are hers: they live on her meeting note, as in the helper. Turning Get ready off hides the cards; it never deletes her comment or drawing.

## How it looks

### On her tablet

The helper's layout (`meeting_helper`): full screen, always dark, the header with "Back to Aglowy" and dots for the cards.

| Frame | What it shows |
| --- | --- |
| `tablet-prep-week.png` | "Get ready for the meetings" as the `h1`, "Ask Mom or Dad to read the cards with you.", and a big tile for each meeting this week: its name, day and time, how many cards ("4 cards", or "My comment is ready" once she has one), and Start ("Look again" once that meeting has passed). The next meeting comes first. A meeting with no cards yet says "Cards aren't ready yet" and has no button |
| `tablet-prep-card.png` | One card. The part in small print with its tone dot and "Card 1 of 4", the part's big icon, then what it's about as the `h1`. Beneath, side by side: "Jehovah cares" with the quality's icon and the line saying how the part shows it, and "I can…" with the thing to do. Back, and Next card ("All done" on the last, back to her Get ready page) |
| `tablet-prep-reading.png` | The Bible Reading card: the `h1`, then "The story · Lamentations 1–2" with up to four numbered sentences, then the quality and "I can…". Draw it! sits in the footer between Back and Next |
| `tablet-prep-study-comment.png` | The Congregation Bible Study card before she has a comment: a blue box, "My comment", "Pick a paragraph with your family. Then say it your own way.", and Get my comment ready |
| `tablet-prep-watchtower.png` | The Watchtower Study card once she has a comment: "My comment · paragraph 7", her words, and Change |

Sizes are the helper's: the `h1` at 42px (36px on the reading card, to leave room for the story), buttons at least 72px tall, Primer `Button` with the helper's large modifier. Styles are BEM classes in `app/assets/stylesheets/components/_meeting_prep.scss`, from primitives only. These are meeting helper child screens (CLAUDE.md, the third approved exception).

**Jehovah's qualities,** a fixed list (`PrepWeek::Card::QUALITIES`), each with its words and our own icon in `app/assets/images/meeting_prep/`, drawn like the helper's (24px outlines, 1.75px strokes, `aria-hidden`), on the attention (gold) colour:

| Key | Her words | Icon |
| --- | --- | --- |
| `loving` | Jehovah is loving | heart |
| `caring` | Jehovah cares | heart with a plus |
| `kind` | Jehovah is kind | open hand |
| `wise` | Jehovah is wise | light bulb |
| `fair` | Jehovah is fair | scales |
| `strong` | Jehovah is strong | mountain |
| `patient` | Jehovah is patient | hourglass |
| `generous` | Jehovah gives | gift |
| `forgiving` | Jehovah forgives | arrow turning back |
| `faithful` | Jehovah keeps his promises | shield with a check |

"I can…" uses the listening game's `action` icon (rays) on the success (green) colour. Each part's icon and tone dot are the helper step's (`MeetingNote::HelperSteps`).

### On a parent's phone

| Frame | What it shows |
| --- | --- |
| `phone-prep-check.png` | "This week's Get ready cards" and the week, a note ("AI wrote these from this week's program. <child's first name> can see them now. Change anything that isn't right.") with a link to each page the AI used, and a box per meeting listing each card: the part, what it's about, the quality and "I can", and Change. With more than one child using the helper, the note names them all ("Eli and Ana can see them now") |
| `phone-prep-change.png` | Change opens a Primer `Dialog` with a Primer form class (`MeetingPreps::CardForm`): What it's about, Jehovah is… (a select of the ten), How it shows, I can…, and for the Bible Reading card the reading and its story sentences. Save or Cancel |
| `phone-prep-settings.png` | Settings → Children: the "Today's meeting" box gains "Get ready cards", with its caption and a link to this week's cards, under "Meeting helper for children" |

## The Settings check box

- `Settings::MeetingHelperForm` gains a second check box, "Get ready cards", with the caption "Each week, AI writes a few simple cards about both meetings, from this week's program on jw.org: what each part is about, something about Jehovah, and one thing to do. Children see them as soon as they're ready. You can read and change them." and the link "This week's cards" while it's on. The one Save goes to `Settings::MeetingHelpersController#update`, which calls the model methods for each box.
- The check box shows only while the helper is on. Unticking the helper turns both off.
- When it's on, a muted line under it says "Turned on by <name> on <date>", like the helper's.
- Turning it on prepares this week straight away (`prepare_meeting_prep_later`, enqueued after the switch's commit).

## The weekly AI job

It follows the listening game's job rules exactly (`docs/design/listening-game.md`, The weekly research job), with these differences:

- **`PrepWeek::PrepareJob`** runs hourly (`config/recurring.yml`, at minute 30, so it doesn't start with the listening game's), and each run takes the households where it's now 3am (`Household.at_local_hour(3)`), as the listening game's job does at 2am. So each household gets its first try at 3am on its own Monday, and a retry at 3am every day after, for each household with Get ready on whose week is missing a card it can still use: a step with no card whose meeting hasn't passed yet (`household.missing_prep_steps(week_of, now)`). A week with no `PrepWeek` misses all five. It stops once the weekend meeting has passed: a week whose midweek meeting is over still gets its Watchtower card.
- **Filling in, never replacing.** A run asks only for the missing steps (they go into the question with the week), and saves a card only for a step that still has none, under the claim. Cards already saved, whether the AI's or changed by a parent, are never touched. The unique (`prep_week_id`, `step`) index stops a second card for a step. A first run that finds cards for some steps saves the `PrepWeek` with those, so she sees them straight away; the next daily runs try for the rest. Each try counts toward the daily limit, so a part the AI never finds costs at most one request a day until its meeting.
- **The week** is the Monday of the household's current week, in its time zone (`Household::Meeting#week_of`). Both meetings of that week share it, as their meeting notes do.
- **The claim** is a `PrepWeek::Preparation`, with the same token, 15-minute takeover and 5-minute request timeout as `ListeningGame::Preparation`. The story may extract the claim into a concern shared with `Household::ListeningGamePreparable`, as long as the listening game's tests still pass unchanged.
- **The owner** is picked the same way: the person who turned Get ready on, then the heads, then the adults, oldest membership first, who has accepted the AI terms. Nobody has: `:not_allowed`, no claim, no chat. Her page then says "Cards aren't ready yet", and the parent's page says "Cards need a head or adult who has turned on AI features", with a link to where the AI terms are accepted, as the listening game's does. Accepting the AI terms enqueues the week for each of the person's households with Get ready on, from the same `after_create_commit` on `Ai::Acceptance`.
- `household.prepare_meeting_prep(week_of)` makes a chat (`purpose: "meeting_prep"`, the owner as `user`, `household` the household) and calls `Chat#ask_within_purpose` with the week's dates and `MeetingNote.program_url(week_of)`, which shows both meetings' material on wol.jw.org. Aglowy builds that address but never requests it.

### `Ai::Purpose::MeetingPrep`

Instructions in `config/ai/meeting_prep.md`:

- `allowed_hosts`: the usual three. `max_searches`: 6 (the program, the Bible Study chapter and the Watchtower study article are pages of their own).
- `schema`: `off_topic`, and `cards`, a list of `{ step, about, quality, quality_line, i_can, reading, story }`:
  - `step`: one of the steps the question asks for, from `talk`, `bible_reading`, `living`, `congregation_bible_study`, `watchtower_study`
  - `about`: at most 20 words. `quality_line` and `i_can`: at most 14 words each
  - `quality`: one of the ten keys
  - `reading` (the chapters, like "Lamentations 1–2") and `story` (2 to 4 sentences, at most 14 words each): only for `bible_reading`, empty otherwise
- **The instructions say:**
  - find the week's program, then the five parts: the Treasures talk, the Bible Reading, the Living as Christians parts (one card for all of them), the Congregation Bible Study chapter, and the Watchtower study article for that weekend
  - write for a child of 4 to 8, in short words she knows, in its own words, never quoting a page or a verse
  - `about` says what the part teaches, not what the speaker does
  - `quality` is one the part really shows, and `quality_line` says how, in one short sentence
  - `i_can` is something small, kind and safe that a young child can do at home or at the meetings this week, with her family's help
  - the story tells what happens in the reading, in order, simply; hard things are said gently, with no frightening details
  - no names of people in the congregation, no money, nothing about other children's families
  - return fewer cards, or none, rather than guess
- `daily_limit`: 3 a day per household. `keep_for`: 7 days (the chat; the cards have their own rule below).
- **Every safety measure in `docs/design/ai.md` applies.** Moderation is skipped because no person's text is sent. The copy check runs on every text field. A card loses nothing quietly: if the check removes `about`, `quality_line`, `i_can` or the Bible Reading card's `reading`, the card is dropped; if it removes a story sentence, that sentence goes, and a story left with fewer than 2 sentences drops the Bible Reading card, so that step stays missing and the next daily run asks for it again. Every field is escaped when shown.
- **Checks before saving:** each step at most once, and only a step that was asked for and still has no card; `quality` one of the ten; the schema's word limits (`about` at most 20 words, `quality_line` and `i_can` at most 14, each story sentence at most 14), counted as runs of non-whitespace separated by any whitespace (`text.split.size`), and the columns' lengths; a story only on `bible_reading`. A card that fails is dropped. The Bible Reading card needs its `reading` and its story: a missing `reading` drops the card too, and a missing story, one with fewer than 2 or more than 4 sentences, or a sentence over its limit drops the card, so the step stays missing and the next daily run asks for it again. A saved card is never revisited, so a story is never added to, or taken from, a card a parent may have changed. These limits are on what the AI returns; a parent's change is held only to the columns' lengths. A run left with no new cards saves nothing (a first run makes no `PrepWeek`) and lets the claim go, so the next daily run tries again.
- **Every page the AI used is linked** on the parent's page: each source that passes `Ai::SourceLink` is kept as a `PrepWeek::Source`, its title and URL only.

## Models

### `Household::MeetingPrep`

The switch, as a record like `Household::MeetingHelper`: it exists while Get ready is on.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null, cascade, **unique** | One switch per household |
| `enabled_by_id` | uuid | FK → users, not null | "Turned on by Daniel Rivera on November 20" |
| `created_at`, `updated_at` | datetime | | |

- `household.enable_meeting_prep(by:)` takes the household's row lock (`with_lock`), checks under it that the helper is on, then uses `create_or_find_by!`. It refuses (returns false, saving nothing) while the helper is off.
- `household.disable_meeting_prep` deletes it. `household.disable_meeting_helper` takes the same lock and deletes both switches inside it. So an enable that started before a disable either finishes first and is then turned off with the helper, or waits and finds the helper off.
- `household.meeting_prep?` is true only while both switches exist.

### `PrepWeek`

One week's cards for one household.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null, cascade | |
| `week_of` | date | not null; unique with `household_id` | The Monday |
| `chat_id` | uuid | FK → chats, nullable, nullify | The AI request; purged after 7 days |
| `created_at`, `updated_at` | datetime | | |

- `PrepWeek::PurgeJob` deletes weeks more than 8 weeks old, daily at 4:50am. Her comments and drawings are on her meeting notes, so nothing of hers goes with them.
- `household.prep_week_for(week_of)` reads it, with its cards and sources.

### `PrepWeek::Card`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `prep_week_id` | uuid | FK, not null, cascade | |
| `meeting` | string | not null, check in (`midweek`, `weekend`) | |
| `step` | string | not null, check in the five steps; check that `watchtower_study` is `weekend` and the others `midweek`; unique with `prep_week_id` | One card per part |
| `about` | text | not null, encrypted, 1 to 160 characters (validated) | |
| `quality` | string | not null, check in the ten keys | Its words and icon come from `QUALITIES`, never from the AI |
| `quality_line` | text | not null, encrypted, 1 to 120 characters (validated) | |
| `i_can` | text | not null, encrypted, 1 to 120 characters (validated) | |
| `reading` | text | nullable, encrypted, at most 40 characters (validated) | Bible Reading only |
| `story` | text | nullable, encrypted; a JSON list (`serialize :story, coder: JSON`), at most 4 sentences of at most 120 characters (validated) | Bible Reading only |
| `changed_by_id` | uuid | FK → users, nullable, nullify | Set when a head or adult changes it |
| `created_at`, `updated_at` | datetime | | |

- A check keeps `reading` and `story` null on every step but `bible_reading`.
- **The card text is encrypted** (`encrypts :about, :quality_line, :i_can, :reading, :story`). The AI writes it, but a parent can rewrite any of it in their own words, and `vision.md` says personal text is encrypted. So, as with `MeetingNote::Answer`, the lengths are checked in the model only, because the database sees the ciphertext. `step` and `quality` stay plain: they're fixed values, and the code reads them.
- `prep_week.cards_for(meeting)` lists a meeting's cards in step order (`MeetingNote::HelperSteps` order).

### `PrepWeek::Source` and `PrepWeek::Preparation`

The same columns and rules as `ListeningGame::Source` and `ListeningGame::Preparation`, with `prep_week_id` and `household_id` respectively.

### Her comment for the Watchtower Study

`MeetingNote::Answer` already holds her answer for the Congregation Bible Study, one per note. The weekend note now has one too, for the Watchtower Study:
- `HelperSteps::Step#answerable?` is true for `congregation_bible_study` and `watchtower_study`.
- At the meeting, the weekend helper's Watchtower Study step shows her answer card above its prompt, with "I gave my answer!", as the Bible Study step does (`tablet-game-study.png`), and its mark button reads "I gave my answer!" / "Gave my answer" while the note has an answer.
- "Talk about it" already says "Tell me about your answer for paragraph <n>." when the note has an answer, so the weekend note gets it too.
- Get ready reads and writes the same answer. There's one answer per meeting note, whichever page she wrote it on.

## Pages and routes

```ruby
resources :meeting_preps, only: %i[ index show ], param: :meeting do   # :meeting is midweek or weekend
  scope module: :meeting_preps do
    resources :cards, only: %i[ show edit update ]                     # :id is the step key
    resource :note, only: :create                                      # starts her note, then her comment or drawing
  end
end
```

| Page | Route | What's on it |
| --- | --- | --- |
| Get ready | `GET /:household_id/meeting_preps` (`MeetingPrepsController#index`) | For a child: frame `tablet-prep-week.png`, in the helper's layout. For a head or adult: frame `phone-prep-check.png`, in the household layout. "Cards aren't ready yet" while the week has none, or, on the parent's page, "Cards need a head or adult who has turned on AI features" with a link to where the AI terms are accepted, when nobody can make them |
| A meeting | `GET …/meeting_preps/:meeting` (`#show`) | A child only: redirects to the meeting's first card. A meeting with no cards redirects to Get ready |
| A card | `GET …/meeting_preps/:meeting/cards/:id` (`MeetingPreps::CardsController#show`) | A child only: frames `tablet-prep-card.png`, `tablet-prep-reading.png`, `tablet-prep-study-comment.png`, `tablet-prep-watchtower.png`. A step with no card is a 404 |
| Change a card | `GET …/cards/:id/edit`, `PATCH …/cards/:id` (`MeetingPreps::CardsController#edit`, `#update`) | Heads and adults: frame `phone-prep-change.png`. Saving sets `changed_by` and returns to Get ready |
| Get my comment ready, Draw it! | `POST …/meeting_preps/:meeting/note` (`MeetingPreps::NotesController#create`, `to` = `answer` or `drawing`) | A child only. `Current.user.start_meeting_note(kind: meeting, week_of:)`, then her answer's edit page (`to=answer`, on the meeting's answerable step) or the Bible Reading drawing (`to=drawing`), each with `from=prep`. Change on a written comment links straight to the answer's edit page with `from=prep` |

- **Back to her card.** The answer form and the drawing page carry `from=prep` as a hidden field. When it's `prep`, saving (and Back, and "All done") returns to the Get ready card for that step instead of the helper step. `from` is checked against that one value; it's never a URL.
- **Today's meeting is unchanged.** Starting her note early from Get ready is fine: Today's meeting already redirects to an existing note for the meeting.
- **Where she finds it.** For a child with the helper and Get ready on, while the week has cards:
  - Home shows a "Get ready" card ("Read this week's cards with Mom or Dad.", with Get ready) on days that aren't meeting days. On meeting days, the Today's meeting card gains a second button, Get ready, beside Start
  - the sidebar's Mine group gains "Get ready" (Octicon `light-bulb`) under Today's meeting
- **Where parents find it.** Home's Today's meeting card for heads and adults gains "This week's Get ready cards", and Settings → Children links to it.

## Changes to other docs in this PR

- `docs/design/meeting-helper.md`: "Preparing a Watchtower comment with a parent beforehand" in its Later list points here; the Watchtower Study step shows her answer (above).
- `docs/design/listening-game.md`: "An answer for the Watchtower Study" in its Later list points here.
- `docs/design/ai.md`: `meeting_prep` joins the list of purposes. Safety measure 8 notes that children see Get ready's cards (Casey, 20 Nov), written by a job a head or adult owns, as they see the listening game's labels.
- `docs/design/settings.md`: the Children section's row mentions the Get ready check box.
- `CLAUDE.md`: the third approved form exception names Get ready's screens with the meeting helper's.
- `docs/product/vision.md`: roadmap row 24, PREP-01.

## Traps

1. **Never fetch the program.** `MeetingNote.program_url` goes into the AI's question as text. Aglowy never requests it.
2. **She sees the cards straight away,** so the AI's mistakes reach her before a parent looks. Keep the instructions strict, keep the checks, and make Change easy to find. Never block the meeting on the job: no cards means "Cards aren't ready yet", and the helper works as before.
3. **The quality's words and icon are ours.** The AI only picks a key; `QUALITIES` gives the words. A key outside the ten drops the card.
4. **Card text is untrusted text.** Escape it everywhere, including the parent's page and the dialog.
5. **Her comment is hers.** It's her meeting note's `MeetingNote::Answer`: encrypted, following her between households, and read by a parent only when she shares the note.
6. **`from=prep` is a value, not a URL.** Never redirect to anything taken from params.
7. **The week.** Both meetings share the Monday's `week_of`, in the household's time zone. The job keeps trying until the weekend meeting has passed.
8. **Turning the helper off turns Get ready off,** in the same transaction, so `meeting_prep?` can't be true while the helper is off.
9. **Tests never call a provider.** The job's tests use a recorded reply in `test/fixtures/files/ai/meeting_prep.json`.

## States each story checks

- **The switch:** off; on; helper off (no check box; turning the helper off turns it off; an enable and a helper disable at once never leave Get ready on); turned on by an adult; a child (no Children section)
- **The job:** first run for a week; run twice; two runs at once (one request); a claim left by a run that died; a run whose claim was taken over; nobody has accepted the AI terms; the AI terms accepted later; a week that has all its cards (no request); a week missing only its Watchtower card (asks for that one; the others untouched, a parent's change kept); a missing midweek step after the midweek meeting (not asked for); the AI returns fewer cards, a repeated step, an unknown quality, an `about` over 20 words, a missing, one-sentence or five-sentence story (the reading card dropped and asked for again next day), a story on the wrong step, or nothing; a household behind UTC (its first try at 3am on its own Monday); the copy check removes a field, or a story sentence; the midweek meeting over but not the weekend (still prepared); both over (no retry); Get ready off (no job)
- **Her pages:** a child with both on; the helper off, Get ready off (404); a head or adult on a card page (404); no cards yet; one meeting with cards and one without; the first and last card; the reading card with its story, and without one (a parent cleared it)
- **Her comment:** none yet; written from Get ready; written from the helper and seen in Get ready; changed; the Watchtower answer at the meeting; a shared weekend note with an answer read by a head
- **Draw it!:** from the reading card; back to the card after "All done"; the same drawing in the helper's Bible Reading step
- **The parent's page:** a head, an adult, a child (404), Get ready off (404); no cards yet; a card changed; two children using the helper
