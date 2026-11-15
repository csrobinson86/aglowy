# Today's meeting and the meeting helper for children

**Today's meeting** opens the right congregation meeting for everyone in the household. A head or adult sets when the midweek and weekend meetings happen, in Household settings. On a meeting day, Home shows a "Today's meeting" card, and the sidebar always has a "Today's meeting" item that opens the current or next meeting.

- **Most people** land on their own meeting note for that meeting, ready to take notes.
- **A child, when the household has turned on the meeting helper,** gets the helper instead. It runs on the child's own tablet: one calm, picture-led prompt per part, a big "I heard it!" button, and a page to draw what they saw. It's saved as their own meeting note, and they can show it to their family afterwards.

Read this before touching meeting times on `Household`, `Household::Meeting`, `Household::MeetingHelper`, `MeetingNote::Mark`, `MeetingNote::Drawing`, `MeetingNote::HelperSteps`, `TodaysMeetingsController`, the `meeting_helper` layout, or the Meetings and Children sections of Household settings. Stories live under the **KIDS-01** epic. Mockup frames are in `docs/design/meeting-helper/`.

This builds on these docs:
- `docs/design/meeting-notes.md`: every Today's meeting note *is* a `MeetingNote`.
- `docs/design/invitations.md`: child username logins and Household settings.
- `docs/design/app-shell.md`.

## Decisions (Casey, 15 Nov)

- **Today's meeting is for everyone in the household.**
  - Heads and adults set the meeting times in Household settings: a day and a start time for the midweek meeting and for the weekend meeting.
  - Children with the helper on get the helper. Everyone else, including children while the helper is off, gets their own meeting note.
- **The sidebar item always shows; the Home card shows only on meeting days.** Home stays calm on other days.
- **Before any times are set,** Today's meeting asks "Which meeting is it?", with Midweek and Weekend.
- **The helper is for children aged about 4 to 8**, on a children's tablet, signed in with their own username login.
- **The helper keeps its own switch, off by default.** A head or an adult turns it on in Household settings.
- **Pictures over words.** Many children this age can't read yet, so every part has a big icon and one short prompt a parent can read aloud before the meeting.
- **Drawing is the main way to respond.** Typing stays on the normal meeting note page for older children.
- **Calm, and nothing that nags:** a dark screen, no sounds, no animation, and no points, streaks or rewards (`docs/product/vision.md`, goal 4).
- **A parent reads it** when the child taps "Show my family", using the existing meeting-note sharing. The shared note shows "Talk about it with <child>" questions taken from the prompts. No AI.

## What KIDS-01 builds, and what comes later

| In KIDS-01 | Later |
| --- | --- |
| Meeting times in Household settings, for heads and adults | Weeks with no meetings (assemblies, conventions) and circuit overseer visit weeks |
| Today's meeting for everyone: sidebar item, Home card on meeting days, the right note | Preparing a Watchtower comment with a parent beforehand ("Your paragraph is 7") |
| The helper switch, for heads and adults | Prompts written for that week's program |
| The helper: one part at a time, "I heard it!" marks, drawing | A child mode on a parent's phone, for children without a login |
| The helper's end screen and "Show my family" | Light theme for the helper |
| A parent reading a helper note, with "Talk about it" | Reminders before a meeting (with notifications) |

## Who can do what

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| Set the meeting times | yes | yes | no |
| Turn the helper on or off | yes | yes | no |
| Open Household settings | yes, the whole page | yes, the Meetings and Children sections only (**new**) | no |
| Open Today's meeting | yes, their meeting note | yes, their meeting note | yes: the helper while it's on, otherwise their meeting note |
| Use the helper's steps, marks, drawing and end screen | no | no | yes, while the helper is on |
| Read a helper note | their own | their own | their own; and, like every meeting note, any note shared with the household |

- The helper's own pages (steps, marks, drawing editing, the end screen) are **for children only, while the helper is on**. Anyone else gets a 404 there.
- **The drawing image route is not a helper page.** It follows the meeting-note reading rule instead, so a parent can see a shared drawing, even after the helper is turned off. See Trap 1.
- **Hiding a link isn't authorization** (app-shell.md): every controller checks its own policy.
- Turning the helper off hides the helper. It never deletes a child's marks or drawings, which are the child's own content.

## Meeting times

### On `Household`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `midweek_meeting_wday` | smallint | nullable, check between 0 and 6 | Ruby's `wday`: 0 is Sunday |
| `midweek_meeting_time` | time | nullable | Wall-clock time in the household's time zone |
| `weekend_meeting_wday` | smallint | nullable, check between 0 and 6 | |
| `weekend_meeting_time` | time | nullable | |
| check | | all four null, or all four set (`num_nulls(...) in (0, 4)`) | Times are set together |

These are settings, not state, so plain columns are right here; State as Records doesn't apply. `household.meeting_times_set?` is true when they're set.

### `Household::Meeting`

A PORO (`Data.define(:kind, :starts_at)`) in `app/models/household/meeting.rb`, with:
- `week_of`: `starts_at.to_date.beginning_of_week(:monday)`. A Sunday weekend meeting belongs to the week that started the Monday before, matching `MeetingNote`'s `week_of`.
- `ends_at`: `starts_at + Household::Meeting::LENGTH`, where `LENGTH` is 2 hours.
- `title`: "Midweek meeting" or "Weekend meeting".

`household.current_or_next_meeting(now = Time.current)` works it out:
1. In the household's time zone, build each kind's occurrence in this week and in next week. The date is the Monday plus `(wday - 1) % 7` days, and the time comes from `ActiveSupport::TimeZone#local`, so changes to and from daylight saving time are right.
2. Return the earliest occurrence whose `ends_at` is after `now`.
3. Return nil when the times aren't set.

`household.meeting_day?(now)` is true when `current_or_next_meeting` starts today, in the household's time zone.

## The helper's steps

A helper note follows a fixed list of steps per meeting kind, defined in code like `MeetingNote::Outline`. The steps are not the outline's parts: songs and prayers are steps but not parts, and Field Ministry is one step even when the program has several parts.

`MeetingNote::HelperSteps` is a PORO in `app/models/meeting_note/helper_steps.rb`. Each `Step` is a `Data` with `key`, `title`, `short_title`, `prompt`, `draw_prompt`, `mark_label`, `marked_label`, `icon`, `tone` and `talk_question`.

**Midweek (8 steps)**

| Key | Title (small print) | Prompt | Draw prompt | Mark button / marked | Tone | Talk about it |
| --- | --- | --- | --- | --- | --- | --- |
| `opening_song` | Song and prayer | Sing along with everyone. | Draw something you sang about. | We sang! / Sang it | song | What was the first song about? |
| `talk` | Treasures From God's Word | Listen for someone from the Bible. | Draw who you heard about. | I heard it! / Heard it | treasures | Who from the Bible did you hear about? |
| `spiritual_gems` | Spiritual Gems | Listen for something kind Jehovah did. | Draw what Jehovah did. | I heard it! / Heard it | treasures | What kind thing did Jehovah do? |
| `bible_reading` | Bible Reading | Listen for the name of a Bible book. | Draw something from the reading. | I heard it! / Heard it | treasures | Which Bible book did you hear? |
| `field_ministry` | Apply Yourself to the Field Ministry | Watch the people talk. What did they share? | Draw what they shared. | I watched! / Watched it | ministry | What did the people at the door talk about? |
| `living` | Living as Christians | What should we do this week? | Draw what we can do this week. | I heard it! / Heard it | living | What should we do this week? |
| `congregation_bible_study` | Congregation Bible Study | Look at the pictures. Which one do you like? | Draw the picture you liked. | I watched! / Watched it | living | Which picture did you like? |
| `closing_song` | Song and prayer | Sing the last song together. | Draw something you sang about. | We sang! / Sang it | song | What was the last song about? |

**Weekend (4 steps)**

| Key | Title | Prompt | Draw prompt | Mark button / marked | Tone | Talk about it |
| --- | --- | --- | --- | --- | --- | --- |
| `opening_song` | Song and prayer | Sing along with everyone. | Draw something you sang about. | We sang! / Sang it | song | What was the first song about? |
| `public_talk` | Public Talk | Listen for a story from the Bible. | Draw the story you heard. | I heard it! / Heard it | weekend | Which Bible story did you hear? |
| `watchtower_study` | Watchtower Study | Look at the pictures. Raise your hand if you know an answer. | Draw a picture from the study. | I watched! / Watched it | weekend | Which picture did you like? |
| `closing_song` | Song and prayer | Sing the last song together. | Draw something you sang about. | We sang! / Sang it | song | What was the last song about? |

Tones map to the meeting-note section dots: `treasures` → muted, `ministry` and `weekend` → attention, `living` → danger, `song` → accent. When a step has a drawing, its "Talk about it" question becomes "Tell me about your drawing" followed by the step's short title.

Icons are our own decorative SVGs in `app/assets/images/meeting_helper/` (music, ear, gem, book, people talking, house with heart, picture, raised hand). They're drawn as 24px outlines with 1.75px strokes like the mockup and rendered inline with `aria-hidden="true"`. Octicons has no ear, gem or raised hand.

## Models

### `Household::MeetingHelper`

The switch is a record, not a boolean (CLAUDE.md, State as Records): it exists while the helper is on.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null, cascade, **unique** | One switch per household |
| `enabled_by_id` | uuid | FK → users, not null | "Turned on by Daniel Rivera on November 15" |
| `created_at`, `updated_at` | datetime | | When it was turned on |

- `Household has_one :meeting_helper`.
- `household.enable_meeting_helper(by:)` uses `create_or_find_by!`, so two adults turning it on at once can't make two rows or raise.
- `household.disable_meeting_helper` deletes it.
- `household.meeting_helper?` reads it.

### `MeetingNote::Mark`

"I heard it!" for one step of one note.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `meeting_note_id` | uuid | FK → meeting_notes, not null, cascade | |
| `step` | string | not null | A key from `HelperSteps` for the note's kind (validated in the model) |
| `created_at` | datetime | | |
| unique index | | (`meeting_note_id`, `step`) | Tapping twice can't make two |

### `MeetingNote::Drawing`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `meeting_note_id` | uuid | FK → meeting_notes, not null, cascade | |
| `step` | string | not null | As above |
| `image` | Active Storage | `has_one_attached :image`; PNG only, at most 2 MB, validated in the model | The canvas exports a PNG |
| `created_at`, `updated_at` | datetime | | |
| unique index | | (`meeting_note_id`, `step`) | One drawing per step; drawing again replaces it |

- `MeetingNote has_many :marks` and `has_many :drawings`, both `dependent: :destroy`, so attachments are purged.
- A drawing is personal content: it doesn't count toward the household's storage quota.
- Images aren't encrypted by the app, because they aren't text. They live in the private bucket and are only served through an authorizing controller, like family study files (family-studies.md, Files; gotcha 22).

Methods on `MeetingNote`:
- `helper_steps` returns `HelperSteps.for(kind)`.
- `mark(step)` and `unmark(step)` add or remove a mark.
- `helper_used?` is true when the note has any marks or drawings.
- `talk_questions` returns up to 3 questions: drawn steps first, then marked ones, in step order.

## Pages

| Page | Route | What's on it |
| --- | --- | --- |
| Household settings, Meetings section | `GET /:household_id/settings` (existing); `PATCH /:household_id/meeting_times` (`Households::MeetingTimesController#update`) | Frames `household-settings-head.png`, `household-settings-adult.png`. A `BorderBox` "Meetings" with a line explaining what the times are for, then a Primer form (`Households::MeetingTimesForm`): for each meeting, a Day select (Monday to Sunday) and a "Starts at" time field, then Save. All four are required together |
| Household settings, Children section | `PATCH /:household_id/meeting_helper` (`Households::MeetingHelpersController#update`) | A `BorderBox` "Children". The mockup draws a switch; build it as a Primer form (`Households::MeetingHelperForm`) with one check box, "Meeting helper for children", its caption, and a Save button, because Primer's ToggleSwitch only POSTs a value to one URL, which doesn't fit our CRUD routes. When the helper is on, a muted line says "Turned on by <name> on <date>". Adults see the Meetings and Children sections and a line saying a head changes the name, time zone and roles |
| Today's meeting | `GET /:household_id/todays_meeting` (`TodaysMeetingsController#show`) | See below. A child with the helper gets the `meeting_helper` layout; everyone else gets the household layout |
| Start | `POST /:household_id/todays_meeting` (`kind` and `week_of` from the page, checked against what the page offered) | `Current.user.start_meeting_note(kind:, week_of:)`, then the note's first step (a child with the helper) or the note's edit page (everyone else) |
| A step | `GET /:household_id/meeting_notes/:meeting_note_id/steps/:id` (`MeetingNotes::StepsController#show`; `:id` is the step key) | Frames `tablet-listen.png`, `tablet-listen-light.png` (light shown for reference only), `tablet-weekend-watchtower.png`. The step's title in small print with its tone dot, the big icon, the prompt as the `h1`, the mark button and "Draw it" ("My drawing" once one exists), and Back and Next ("Finish" on the last step). Back on the first step goes to Today's meeting |
| Mark | `POST` / `DELETE …/steps/:step_id/mark` (`MeetingNotes::Steps::MarksController`) | Turbo Stream replaces the mark button: "I heard it!" ↔ "✓ Heard it" (`aria-pressed`) |
| Draw | `GET …/steps/:step_id/drawing/edit`, `PATCH …/steps/:step_id/drawing` (`MeetingNotes::Steps::DrawingsController`) | Frame `tablet-draw.png`. The draw prompt as the `h1`, "All done", the canvas, seven colours, Undo and Start over. An existing drawing loads onto the canvas so the child can add to it. "All done" saves and goes back to the step |
| A drawing's image | `GET …/steps/:step_id/drawing` (`show`) | Not a helper page (Trap 1). Finds the note among the person's own notes or those shared into this household, authorizes with `MeetingNotePolicy#show?`, then redirects to a short-lived service URL |
| The end | `GET /:household_id/meeting_notes/:meeting_note_id/summary` (`MeetingNotes::SummariesController#show`) | Frame `tablet-done.png`. "You listened all the way through!", a tile per step with its mark or drawing, "Show my family" (the existing `POST …/sharing`, which comes back here) or "Your family can see it now", and "Finished" to Home |
| Home on a meeting day | `GET /:household_id` | Frames `adult-home-meeting.png`, `child-home.png`. Above the columns, a "Today's meeting" card shows the meeting's title and start time ("Midweek meeting · 7:00 PM"). For a child with the helper, it says "Listen for things and draw what you see, one part at a time." with **Start**. For everyone else, it says "Take notes as you go. They stay yours in every household." with **Open my notes**. The button posts to Start |
| Sidebar | every household page | "Today's meeting" (Octicon `sun`) comes first in the Mine group for every member, always |
| A helper note, read | `GET /:household_id/meeting_notes/:id` (existing) | Frame `phone-parent.png`. When `helper_used?`, a "From Today's meeting" section shows "Talk about it with <first name>" (from `talk_questions`) and each step with its mark or drawing, for the author and for members it's shared with. Empty outline parts stay hidden as they are today |

### The Today's meeting page

`GET` never creates anything. Turbo prefetches links on hover, so a page that made notes on `GET` would make them for anyone who hovered the sidebar.

- **Times set:**
  - If the person already has a note for `current_or_next_meeting`, redirect to it: its first step for a child with the helper, its edit page for everyone else.
  - Otherwise show that one meeting: its title, day and start time ("Midweek meeting · Friday 7:00 PM"), and one big button, "Start my notes" or, for a child with the helper, "Start".
- **No times set:**
  - "Which meeting is it?" with two buttons, Midweek meeting and Weekend meeting, for this week (`Current.membership.this_week`). This is frame `tablet-pick.png` for a child with the helper.
  - Heads and adults also see "Set your meeting times" linking to Household settings.

### The `meeting_helper` layout

- Full screen, no sidebar.
  - A header with "Back to Aglowy": an icon link to Home with an `aria-label`.
  - The step dots, decorative, with visually hidden text like "Part 2 of 8: Treasures From God's Word".
  - The meeting's name.
- `<body data-color-mode="dark" data-light-theme="light" data-dark-theme="dark">`: always dark in KIDS-01, because a bright screen glows in a meeting hall.
- `lang`, `<main>` and landmarks as everywhere. The page title is "Today's meeting".
- Sizes, from base-size primitives:
  - prompt type 46px
  - mark and draw buttons at least 96px tall
  - Back and Next at least 72px tall
  - colour swatches 60px
- Use Primer `Button` with a BEM modifier for the large size. Other styles are BEM classes in `app/assets/stylesheets/components/_meeting_helper.scss`, built only from primitives.
- No sounds, no CSS transitions or animations, no counters.

## Drawing

- A `<canvas>` with a Stimulus controller (`meeting_helper/drawing_controller.js`).
- Pointer events (`pointerdown`, `pointermove`, `pointerup`, `pointercancel`) with `setPointerCapture`, and `touch-action: none` so the tablet doesn't scroll.
- Draw at a fixed 1116×470 logical size, scaled by `devicePixelRatio`, with 9px round strokes in the picked colour on the dark paper colour.
- Undo removes the last stroke and redraws; Start over clears.
- "All done":
  1. `canvas.toBlob("image/png")`.
  2. Put the file into the form's hidden file input with `DataTransfer`.
  3. Submit. The form is a Primer form class with that file input inside, the same pattern as the file drop zone.
- The canvas has `role="img"` and `aria-label="Drawing space. Draw with your finger."`. Drawing is optional; everything else works from the keyboard.

## CLAUDE.md and app-shell.md changes in this design PR

- **Forms:** a third approved exception, for the meeting helper's child screens (large touch targets in BEM Sass from primitives) and its drawing canvas (Stimulus). Primer has neither. Both still use Primer `Button` and a Primer form wherever a button or form appears.
- **Layouts:**
  - The `meeting_helper` layout is the one household-scoped exception to "Household pages use the `household` layout". It's used only for a child with the helper on.
  - It's also the one exception to automatic theming: it's always dark.

## Traps

1. **Find the note the right way for each route.**
   - Helper pages: `Current.user.meeting_notes.find(params[:meeting_note_id])`, so anyone else's note is a 404.
   - The drawing image route: `Current.user.meeting_notes.find_by(id:) || MeetingNote.shared_with(Current.household).find(id)`, the same lookup `MeetingNotesController#show` uses, then `authorize note, :show?`. It doesn't check `MeetingHelperPolicy`, so a parent can read a shared drawing, and it still works after the helper is turned off.
2. **A step key that isn't in the note's kind is a 404**, never a 500. `HelperSteps.for(kind).fetch(key)` raises `ActiveRecord::RecordNotFound`.
3. **The meeting week comes from `Household::Meeting#week_of`,** in the household's time zone. Without times, the picker uses `Current.membership.this_week`. `start_meeting_note` finds or creates on the unique index, so a double tap can't make two notes.
4. **Check what Start was given.** `POST todays_meeting` accepts only the `kind` and `week_of` the page could have offered: the current or next meeting, or, without times, this week's two. Anything else is a 404.
5. **Daylight saving time:** build meeting times with `zone.local(date.year, date.month, date.day, hour, min)`, never by adding hours to a UTC time.
6. **The helper needs both** a child membership and the household's helper switch. A child whose role changes to adult gets their meeting note instead, and keeps their old notes.
7. **Turning the helper off deletes nothing** of the children's. Turning it on twice at once makes one row (`create_or_find_by!` with the unique index).
8. **Validate drawings on the server:** the content type `image/png` from the blob's analysis, not the request header, and at most 2 MB. A bad file is a validation error, not a 500.
9. **Never render `url_for(drawing.image)`** in a page; always use the authorizing `drawing` route (gotcha 22).
10. **Household settings opens to adults**, for the Meetings and Children sections only.
    - `HouseholdPolicy#update?` (name and time zone) stays heads-only.
    - Add `HouseholdPolicy#edit?` for heads and adults.
    - `Households::MeetingTimesController` and `Households::MeetingHelpersController` authorize `HouseholdPolicy#manage_meetings?`, for heads and adults.
    - The sidebar footer shows Household settings to heads and adults.
11. **No animation sneaks in.** Primer's default button transitions are fine; add nothing that moves on its own.

## States each story checks

- **Meeting times:**
  - not set, so the picker shows
  - set, on a meeting day before, during and just after the meeting (within 2 hours of the start)
  - set, on a day with no meeting, so the next meeting shows
  - the Sunday weekend meeting's `week_of`
  - a week when daylight saving time changes
- **Today's meeting:**
  - a head, an adult, a child with the helper off (meeting note) and a child with it on (helper)
  - with and without an existing note
- **Helper off:** the helper's pages 404 for a child, who gets the meeting note instead.
- **Each step,** for midweek and weekend:
  - Back on the first step goes to Today's meeting
  - Finish on the last step goes to the summary
- **Marks and drawings:**
  - marked and unmarked
  - drawn and not drawn
  - drawing again replaces the old drawing
- **The summary,** before and after "Show my family".
- **A shared note read by a head:**
  - the questions and drawings show
  - the drawing image route works for them, and still works with the helper turned off
  - the route 404s for someone outside the household
- **The Home card:** only on meeting days; Start for a child with the helper, Open my notes for everyone else.
