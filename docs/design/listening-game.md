# The listening game for children

At the midweek meeting, the meeting helper's listening parts become a game. Each round shows four big cards on the child's tablet. One card is something the part is sure to mention, and the child taps it when she hears it. The rounds follow the part from start to finish, so a long part keeps her listening the whole way through. For the Congregation Bible Study she also writes her own answer before the meeting, and taps "I gave my answer!" once she's given it.

Read this before touching `ListeningGame`, `ListeningGame::Round`, `ListeningGame::Card`, `MeetingNote::Find`, `MeetingNote::Answer`, `Ai::Purpose::ListeningGame`, the helper's step pages, or the parent's listening game page. Stories live under the **GAME-01** epic. Mockup frames are in `docs/design/listening-game/`, and in the "Listening game" row on the design canvas.

This builds on these docs:
- `docs/design/meeting-helper.md`: the helper, its steps, marks, drawing, the end screen and "Show my family".
- `docs/design/ai.md`: every rule there applies. In particular, Aglowy never fetches jw.org or wol.jw.org itself.
- `docs/design/meeting-notes.md`: a helper note is a `MeetingNote`.

## Decisions (Casey, 18 Nov)

- **Four of the midweek steps become a game.** Each round has four cards, one right and three wrong. The rounds follow the part in the order it covers things:

  | Step | Part | Rounds |
  | --- | --- | --- |
  | `talk` | Treasures From God's Word (10 minutes) | 5 |
  | `spiritual_gems` | Spiritual Gems | 2 |
  | `bible_reading` | Bible Reading | 1, or 2 when the reading names a person |
  | `congregation_bible_study` | Congregation Bible Study (30 minutes) | 6 |

- **The cards come from a weekly AI research job.** It asks the AI what that week's parts cover. The AI provider's own search looks at jw.org and wol.jw.org, as it does for family study drafts. Aglowy never opens a jw.org page, and keeps nothing from the search but the program's title and link (`docs/design/ai.md`).
- **A card can be anything a child can picture:** a Bible person, a place, a Bible book, a thing, a feeling, or something to do ("Praying to Jehovah"). The right card is always something the part names or shows. The wrong cards are well-known Bible things that the part doesn't mention at all.
- **Child words, written by the AI in its own words.** "Repentance" becomes "Saying sorry to Jehovah". An idea a child can't spot, like "self-blame", is left out.
- **A score for that meeting only.** The end screen says "You found 12 things today!" and the shared note says the same. Nothing carries over between weeks: no running total, no streaks, no comparing children. This replaces "no points" in the helper's 15 Nov decisions. The rest of that decision stands: no sounds, no animation, nothing that nags.
- **A wrong tap costs nothing.** The card says "Listen again", and the child can try another.
- **A head or adult checks the cards** before the meeting, and can change any round for their household.
- **Her answer for the Congregation Bible Study.** Before the meeting she picks a paragraph with her family and types what she'll say herself. At the meeting, her answer sits at the top of the step with "I gave my answer!". It shows in "Show my family".
- **No cards, no game.** If the job hasn't produced cards for a step, the step stays exactly as it is today: "I heard it!" and drawing.

## What GAME-01 builds, and what comes later

| In GAME-01 | Later |
| --- | --- |
| The weekly research job and its AI purpose | The Watchtower Study and the Public Talk |
| Rounds on the four midweek steps | Cards in other languages |
| The parent's check and change | Picture cards (Aglowy can't use jw.org's artwork, so cards have icons for their kind) |
| Her answer for the Congregation Bible Study | An answer for the Watchtower Study |
| The score on the end screen and in the shared note | |

## How it looks

### On her tablet

| Frame | What it shows |
| --- | --- |
| `tablet-game-round.png` | A round. The step's title in small print with "Round 2 of 5", "Tap it when you hear it." as the `h1`, and four cards in a 2 × 2 grid. Each card is a real `<button>` at least 176px tall, with an icon for its kind and its words. Back, "Draw it" and "Next part" stay in the footer |
| `tablet-game-found.png` | She tapped the right card. It turns green with a check and "You heard it!"; the others dim. The `h1` becomes "You heard it!", and Next becomes "Next round" (or "Next part" after the last round) |
| `tablet-game-again.png` | She tapped a wrong card. It gets a dashed border and "Listen again". Nothing is saved, and she can tap another |
| `tablet-game-write-answer.png` | Before the meeting, on the Bible Study step: "My answer for Bible study", a Paragraph number field and "What I'll say", which she types herself, then "Save my answer" |
| `tablet-game-study.png` | At the meeting: her answer card at the top ("My answer · paragraph 7" and her words) with "I gave my answer!", then the round's cards, smaller to fit |
| `tablet-game-done.png` | The end screen: "You found 12 things today!", and a tile per step. A game step's tile says "Found 4"; the Bible Study tile adds "Gave my answer" |

Kinds and their icons, our own SVGs beside the helper's (`app/assets/images/meeting_helper/`), with Primer functional colours:

| Kind | Icon | Colour |
| --- | --- | --- |
| `person` | head and shoulders | accent |
| `place` | map pin | attention |
| `book` | open book (the helper's) | muted |
| `thing` | box | muted |
| `feeling` | heart | danger |
| `action` | rays (something to do) | success |

### On a parent's phone

| Frame | What it shows |
| --- | --- |
| `phone-game-check.png` | "This week's listening game": a note that AI found the cards from this week's program, with a link to each page the AI used, and a box per step listing each round as "✓ Jeremiah" with the three wrong cards below, and Change |
| `phone-game-change.png` | Change opens a Primer `Dialog`: "Heard in the talk" with its Kind, and the three other cards. Save or Cancel |
| `phone-game-shared.png` | Her shared note: "Talk about it with Eli" now draws on what she found and her answer, then her answer, then "Listening game · found 12" with what she found in each part |

## The weekly research job

### When it runs

- `ListeningGame::PrepareJob` runs every Monday at 2am (`config/recurring.yml`). For each household with the meeting helper on, it prepares the game for the current week, unless that household has one already.
- The same job runs every day at 2am too, so a week that failed on Monday tries again the next day. It stops trying once the week's midweek meeting has passed.
- **One request at a time for a household and week.** Before any request, the run claims the week: inside `household.with_lock`, it checks there's no game yet and makes a `ListeningGame::Preparation` (unique on `household_id` and `week_of`). If a claim already exists and is less than 15 minutes old, another run is working on it and this one stops. An older claim belongs to a run that died, so this run takes it over by updating its `created_at` and giving it a new `token`. Each claim carries a `token` (a fresh UUID), and the run keeps the token it set. The lock is released before the request goes out, and is never held across a network call. The claim is deleted when the game is saved, and when the request fails or returns nothing usable, so the next daily run can try again.
- **A request can't outlive its claim.** The provider request has a 5-minute timeout, well under the claim's 15 minutes, and a timeout counts as a failed request. As a fence besides: the run saves its game, and deletes the claim, only inside `household.with_lock` and only while the claim still holds the run's `token`. A run whose claim was taken over saves nothing and leaves the claim alone.
- **Accepting the AI terms prepares the week.** When a head or adult accepts the AI terms (`Ai::Acceptance`), each of their households with the helper on and no game for the current week gets `prepare_later`, through the same claim. The unique index on `listening_games` (`household_id`, `week_of`) still stops a second game row.
- Turning the helper on prepares the current week straight away (`prepare_later`).

### What it asks

**Whose request it is.** The owner is the first of these who is an active head or adult in the household and has accepted the AI terms (`accepted_ai_terms?`, `docs/design/ai.md`): the person who turned the helper on, then the heads, then the adults, oldest membership first. If none has accepted, nothing is sent: `prepare_listening_game` returns `:not_allowed` before making a chat, and the week has no game. The parent's page then says "Cards need a head or adult who has turned on AI features", with a link to where they're accepted. The check runs before the chat is made and before any provider call.

`household.prepare_listening_game(week_of)` picks the chat's owner, checks the AI terms, and only then makes a chat (`purpose: "listening_game"`, that owner as `user`, `household` = the household) and calls `Chat#ask_within_purpose` with the week's dates and the program's address on wol.jw.org (`MeetingNote.program_url(week_of)`, which Aglowy builds but never requests).

`Ai::Purpose::ListeningGame`, with its instructions in `config/ai/listening_game.md`:

- `allowed_hosts`: the usual three. `max_searches`: 6, since the Bible Study chapter is a page of its own.
- `schema`: for each of the four steps, an ordered list of rounds. Each round is `{ answer: { label, kind }, others: [ { label, kind } × 3 ] }`. A label is at most 4 words; `kind` is one of the six kinds.
- **The instructions say:**
  - find the week's program, then the Treasures talk, Spiritual Gems, Bible Reading and the Congregation Bible Study chapter it points to
  - pick the rounds in the order the part covers them
  - make the answer something the part names or shows, never something it only implies
  - write every label in child words of its own, never quoting the page or a verse
  - pick other cards a 4–8-year-old would know from the Bible, of the same kind where it can, that the part doesn't mention
  - return fewer rounds, or none, rather than guess
- `daily_limit`: 3 a day per household. `keep_for`: 7 days (the chat; the game itself has its own rule below).
- **Every safety measure in `docs/design/ai.md` applies.** Moderation is skipped because no person's text is sent. The copy check runs on every label, and a label it removes drops its round. Every label is escaped when shown.
- **Checks before saving:** each round has exactly one answer and three others; no label repeats within a round; every kind is known. A round that fails is dropped. A step left with no rounds has no game.
- **Every page the AI used is linked.** Each source that passes `Ai::SourceLink` is kept as a `ListeningGame::Source` (its title and URL only), so the parent's page links the program and the Bible Study chapter alike. Nothing else from the search is stored: no page text, no excerpts.

## Models

### `ListeningGame`

One week's game for one household.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null, cascade | |
| `week_of` | date | not null; unique with `household_id` | The Monday, like `MeetingNote#week_of` |
| `chat_id` | uuid | FK → chats, nullable, nullify | The AI request; purged after 7 days |
| `created_at`, `updated_at` | datetime | | |

- `ListeningGame::PurgeJob` deletes games more than 8 weeks old, daily at 4:45am. A child's finds keep their labels (below), so her old notes still read the same.
- `household.listening_game_for(week_of)` reads it.

### `ListeningGame::Source`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `listening_game_id` | uuid | FK, not null, cascade | |
| `position` | smallint | not null; unique with `listening_game_id` | The order the AI cited them |
| `title` | string | not null | From the search result, through `Ai::SourceLink` |
| `url` | string | not null, check it starts with `https://` | On jw.org or wol.jw.org, through `Ai::SourceLink` |

### `ListeningGame::Preparation`

The claim that a run is asking the AI for a household's week (When it runs).

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK, not null, cascade | |
| `week_of` | date | not null; unique with `household_id` | |
| `token` | uuid | not null | Which run holds the claim; a run saves only while its token is still there |
| `created_at` | datetime | not null | A claim older than 15 minutes can be taken over |

### `ListeningGame::Round`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `listening_game_id` | uuid | FK, not null, cascade | |
| `step` | string | not null, check in the four game steps | |
| `position` | smallint | not null; unique with (`listening_game_id`, `step`) | Order within the step, from 1 |
| `changed_by_id` | uuid | FK → users, nullable | Set when a head or adult changes it |

### `ListeningGame::Card`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `round_id` | uuid | FK, not null, cascade | |
| `position` | smallint | not null, check 1–4; unique with `round_id` | Where it sits in the grid, shuffled once when saved so the answer isn't always first |
| `label` | string | not null, at most 40 characters | |
| `kind` | string | not null, check in the six kinds | |
| `answer` | boolean | not null, default false; partial unique index on `round_id` where `answer` | Which card the part mentions. A fact about the card, not a state that changes, so a column is right here |

### `MeetingNote::Find`

The child found the right card in a round.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `meeting_note_id` | uuid | FK, not null, cascade | |
| `step` | string | not null | |
| `position` | smallint | not null | The round |
| `label`, `kind` | string | not null | Copied from the card, so the note reads the same after the game is purged or changed |
| `created_at` | datetime | | |
| unique index | | (`meeting_note_id`, `step`, `position`) | Tapping twice can't make two |

- `meeting_note.found_count` is the score. `meeting_note.finds_for(step)` lists a step's finds in round order.
- A wrong tap saves nothing.

### `MeetingNote::Answer`

Her answer for the Congregation Bible Study.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `meeting_note_id` | uuid | FK, not null, cascade, **unique** | One answer per note |
| `paragraph` | smallint | not null, check > 0 | |
| `body` | text | not null, encrypted (`encrypts :body`), at most 500 characters | Personal text, like every note |
| `created_at`, `updated_at` | datetime | | |

"I gave my answer!" is the existing `MeetingNote::Mark` on the `congregation_bible_study` step. While the note has an answer, that step's mark button reads "I gave my answer!" / "Gave my answer" instead of "I watched!".

## Pages

| Page | Route | What's on it |
| --- | --- | --- |
| A step | `GET …/meeting_notes/:meeting_note_id/steps/:id` (existing) | With rounds for this step, it redirects to the first round she hasn't found, or the last round once she's found them all. Without rounds, it's today's step page |
| A round | `GET …/steps/:step_id/rounds/:id` (`MeetingNotes::Steps::RoundsController#show`; `:id` is the position) | Frames `tablet-game-round.png` and `tablet-game-found.png`. On the Bible Study step, her answer card sits above the cards (`tablet-game-study.png`) |
| Tap a card | `POST …/steps/:step_id/rounds/:round_id/find` (`MeetingNotes::Steps::Rounds::FindsController#create`, `card` param) | The right card makes a `Find` and the Turbo Stream shows the found state. A wrong card makes nothing and shows "Listen again" on it. Both answer 200 |
| Her answer | `GET …/steps/congregation_bible_study/answer/edit`, `PATCH …/answer` (`MeetingNotes::Steps::AnswersController`) | Frame `tablet-game-write-answer.png`. A Primer form class (`MeetingNotes::Steps::AnswerForm`) with Paragraph and What I'll say. Reached from "Write my answer" on the step before she has one, and "Change my answer" after |
| The end | the existing summary | Frame `tablet-game-done.png` |
| This week's game | `GET /:household_id/listening_game` (`ListeningGamesController#show`) | Frame `phone-game-check.png`. The current week's game, with a link to each of its sources; "Cards for this week aren't ready yet" while there's none, or the AI-terms line above when nobody can make them |
| Change a round | `GET …/listening_game/rounds/:id/edit`, `PATCH …/rounds/:id` (`ListeningGames::RoundsController`) | Frame `phone-game-change.png`. A Primer `Dialog` with a Primer form class (`ListeningGames::RoundForm`): the answer's label and kind, and the three other labels. Saving sets `changed_by` |
| A helper note, read | existing | Frame `phone-game-shared.png`: her answer, and "Listening game · found 12" with each step's finds |

- **Who sees the parent's page:** heads and adults while the helper is on (`HouseholdPolicy#manage_meetings?` and `household.meeting_helper?`). Home's Today's meeting card for heads and adults gains "Check this week's listening game" on the days before a midweek meeting, and the Children section of Settings links to it.
- **The child's pages** follow the helper's rules: hers only, a child membership, the helper on. Anyone else gets a 404.
- **She can write her answer any time before the meeting.** Today's meeting opens the next meeting's note, so she can go to the Bible Study step the evening before.
- **"Talk about it"** gains, in step order, "You found <label>. What do you remember about it?" for up to two finds, then "Tell me about your answer for paragraph <n>." when she wrote one. Still up to three questions, still no AI.

## Changes to other docs in this PR

- `docs/design/meeting-helper.md`: the 15 Nov decision becomes "no sounds, no animation, no streaks or running totals; a score for that meeting only (`docs/design/listening-game.md`)". "Prompts written for that week's program" and "Preparing a Watchtower comment" in its Later list point here.
- `docs/design/ai.md`: `listening_game` joins the list of purposes, and the note that a game's chat belongs to the person who turned the helper on.
- `docs/product/vision.md`: roadmap row 22, GAME-01.

## Traps

1. **Never fetch the program.** `MeetingNote.program_url` goes into the AI's question as text. Aglowy never requests it, not even to check it.
2. **The AI can be wrong.** That's why a parent can check and change every round, and why a step with no good rounds falls back to today's step. Never block the meeting on the job.
3. **One answer per round, in the database.** The partial unique index on `listening_game_cards (round_id) where answer`, and the check that each saved round has four cards, guard what the AI returns.
4. **Labels are untrusted text.** Escape them everywhere, including the Turbo Stream that shows "You heard it!".
5. **A find keeps its own label.** Never read a note's finds through the game: the game is purged after 8 weeks and a parent can change a round after she found it.
6. **Tapping fast.** `MeetingNote::Find` is created with `create_or_find_by!` on its unique index, so two taps make one find.
7. **The week.** The game's `week_of` is the midweek meeting's, from `Household::Meeting#week_of` in the household's time zone.
8. **No animation sneaks in.** The found state is a colour and a check, with no transition.
9. **The answer is hers.** It belongs to her meeting note, follows her between households and is encrypted. A parent reads it only when she shares the note.
10. **Tests never call a provider.** The job's tests use a recorded reply in `test/fixtures/files/ai/listening_game.json`.

## States each story checks

- **The job:** first run for a week; run twice; two runs at once (one request); a claim left by a run that died; a run whose claim was taken over (saves nothing); the AI terms accepted later (prepared then); nobody has accepted the AI terms (no chat, no request); a week that already has a game; the AI returns fewer rounds, a bad round, a repeated label, or nothing; the copy check removes a label; the helper turned off (no job); a week whose meeting has passed (no retry)
- **A round:** nothing tapped; a wrong tap; the right tap; tapping the right card twice; the last round of a step; a step with no rounds
- **Her answer:** none yet; written; changed; given at the meeting; a note with an answer shared and read by a head
- **The end screen:** with and without finds; with and without an answer
- **The parent's page:** a head, an adult, a child (404), the helper off (404); no game yet; a round changed
