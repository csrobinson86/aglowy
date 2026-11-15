# Meeting helper for children

"Today's meeting" helps a young child stay with each part of a congregation meeting. It runs on the child's own tablet: one calm, picture-led prompt per part, a big "I heard it!" button, and a page to draw what they saw. What they do is saved as their own meeting note, and they can show it to their family afterwards.

Read this before touching `Household::MeetingHelper`, `MeetingNote::Mark`, `MeetingNote::Drawing`, `MeetingNote::HelperSteps`, the `meeting_helper` layout or the Children section of Household settings. Stories live under the **KIDS-01** epic. Mockup frames are in `docs/design/meeting-helper/`.

This builds on `docs/design/meeting-notes.md` (a helper note *is* a `MeetingNote`), `docs/design/invitations.md` (child username logins, Household settings) and `docs/design/app-shell.md`.

## Decisions (Casey, 15 Nov)

- **For children aged about 4 to 8**, on a children's tablet, signed in with their own username login.
- **Off by default.** A head or an adult turns it on for the household in Household settings.
- **Pictures over words.** Many children this age can't read yet, so every part has a big icon and one short prompt a parent can read aloud before the meeting.
- **Drawing is the main way to respond.** Typing stays on the normal meeting note page for older children.
- **Calm, and nothing that nags:** dark screen, no sounds, no animation, no points, streaks or rewards (`docs/product/vision.md`, goal 4).
- **Entry points:** a "Today's meeting" card at the top of a child's Home, and a "Today's meeting" item in the sidebar's Mine group, both only while the helper is on.
- **A parent reads it** when the child taps "Show my family", which is the existing meeting-note sharing. The shared note shows "Talk about it with <child>" questions taken from the prompts. No AI.

## What KIDS-01 builds, and what comes later

| In KIDS-01 | Later |
| --- | --- |
| The household switch, for heads and adults | Preparing a Watchtower comment with a parent beforehand ("Your paragraph is 7") |
| Today's meeting: pick midweek or weekend, then one part at a time | Prompts written for that week's program |
| "I heard it!" marks | A child mode on a parent's phone, for children without a login |
| Drawing on a part | Light theme for the helper |
| The end screen and "Show my family" | Spoken prompts (would need sound in the hall; not planned) |
| Home card and sidebar item | |
| A parent reading the helper note, with "Talk about it" | |

## Who can do what

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| Turn the helper on or off for the household | yes | yes | no |
| Open Household settings | yes, the whole page | yes, the Children section only (**new**) | no |
| Use Today's meeting | no | no | yes, while the helper is on |
| Read a helper note | their own | their own | their own; also any note shared with the household, like every meeting note |

- Today's meeting is for **children only** in KIDS-01. A head or adult who visits its URLs gets a 404, and so does a child while the helper is off.
- **Hiding the card isn't authorization** (app-shell.md): every helper controller checks the policy too.
- Turning the helper off hides Today's meeting. It never deletes a child's marks or drawings, which are the child's own content.

## The steps

A helper note follows a fixed list of steps per meeting kind, defined in code like `MeetingNote::Outline`. The steps are not the outline's parts: songs and prayers are steps but not parts, and Field Ministry is one step even when the program has several parts. `MeetingNote::HelperSteps` (a PORO in `app/models/meeting_note/helper_steps.rb`) holds them. Each `Step` is a `Data` with `key`, `title`, `short_title`, `prompt`, `draw_prompt`, `mark_label`, `marked_label`, `icon`, `tone` and `talk_question`.

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

Tones map to the meeting-note section dots: `treasures` → muted, `ministry` and `weekend` → attention, `living` → danger, `song` → accent. When a drawing exists, its "Talk about it" question becomes "Tell me about your drawing" followed by the step's short title.

Icons are our own decorative SVGs in `app/assets/images/meeting_helper/` (music, ear, gem, book, people talking, house with heart, picture, raised hand), drawn as 24px outlines with 1.75px strokes like the mockup, rendered inline with `aria-hidden="true"`. Octicons has no ear, gem or raised hand.

## Models

### `Household::MeetingHelper`

The switch is a record, not a boolean (CLAUDE.md, State as Records): it exists while the helper is on.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null, cascade, **unique** | One switch per household |
| `enabled_by_id` | uuid | FK → users, not null | "Turned on by Daniel Rivera on November 15" |
| `created_at`, `updated_at` | datetime | | When it was turned on |

`Household has_one :meeting_helper`. `household.enable_meeting_helper(by:)` uses `create_or_find_by!`, so two adults turning it on at once can't make two rows or raise. `household.disable_meeting_helper` deletes it. `household.meeting_helper?` reads it.

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

`MeetingNote has_many :marks` and `has_many :drawings` (both `dependent: :destroy`, so attachments are purged). A drawing is personal content: it does not count toward the household's storage quota. Images aren't encrypted by the app (they aren't text); they live in the private bucket and are only served through an authorizing controller, like family study files (family-studies.md, Files; gotcha 22).

`MeetingNote#helper_steps` returns `HelperSteps.for(kind)`. `MeetingNote#mark(step)` and `#unmark(step)` add or remove a mark, `MeetingNote#helper_used?` is true when it has any marks or drawings, and `MeetingNote#talk_questions` returns up to 3 questions, from drawn steps first, then marked ones, in step order.

## Pages

| Page | Route | What's on it |
| --- | --- | --- |
| Household settings, Children section | `GET /:household_id/settings` (existing); `PATCH /:household_id/meeting_helper` (`Households::MeetingHelpersController#update`) | Frames `household-settings-head.png`, `household-settings-adult.png`. A Primer `BorderBox` "Children". The mockup draws a switch; build it as a Primer form (`Households::MeetingHelperForm`) with one check box, "Meeting helper for children", its caption, and a Save button. Primer's ToggleSwitch only POSTs a value to one URL, which doesn't fit our CRUD routes. When it's on, a muted line says "Turned on by <name> on <date>". Adults see only this section and a line saying a head changes the name, time zone and roles |
| Today's meeting, pick | `GET /:household_id/todays_meeting` (`TodaysMeetingsController#show`) | Frame `tablet-pick.png`. "Hi, <first name>!", "Which meeting is it?", and two big buttons, Midweek meeting (8 parts) and Weekend meeting (4 parts) |
| Start | `POST /:household_id/todays_meeting` (`kind`) | `Current.user.start_meeting_note(kind:, week_of: Current.membership.this_week)`, then redirect to the first step |
| A step | `GET /:household_id/meeting_notes/:meeting_note_id/steps/:id` (`MeetingNotes::StepsController#show`; `:id` is the step key) | Frames `tablet-listen.png`, `tablet-listen-light.png` (light shown for reference only), `tablet-weekend-watchtower.png`. The step's title in small print with its tone dot, the big icon, the prompt as the `h1`, the mark button and "Draw it" ("My drawing" when one exists), and Back and Next ("Finish" on the last step). Back on the first step goes to the picker |
| Mark | `POST` / `DELETE …/steps/:step_id/mark` (`MeetingNotes::Steps::MarksController`) | Turbo Stream replaces the mark button: "I heard it!" ↔ "✓ Heard it" (`aria-pressed`) |
| Draw | `GET …/steps/:step_id/drawing/edit`, `PATCH …/steps/:step_id/drawing` (`MeetingNotes::Steps::DrawingsController`) | Frame `tablet-draw.png`. The draw prompt as the `h1`, "All done", the canvas, seven colours, Undo and Start over. An existing drawing loads onto the canvas so the child can add to it. "All done" saves and returns to the step |
| A drawing's image | `GET …/steps/:step_id/drawing` (`show`) | Authorizes (the author, or a member the note is shared with), then redirects to a short-lived service URL |
| The end | `GET /:household_id/meeting_notes/:meeting_note_id/summary` (`MeetingNotes::SummariesController#show`) | Frame `tablet-done.png`. "You listened all the way through!", a tile per step with its mark or drawing, "Show my family" (the existing `POST …/sharing`, which returns here) or "Your family can see it now", and "Finished" to Home |
| Child's Home | `GET /:household_id` | Frame `child-home.png`. While the helper is on and the viewer is a child: a "Today's meeting" card above the columns with "Start", and "Today's meeting" (Octicon `sun`) first in the sidebar's Mine group |
| A helper note, read | `GET /:household_id/meeting_notes/:id` (existing) | Frame `phone-parent.png`. When `helper_used?`: a "From Today's meeting" section with "Talk about it with <first name>" (from `talk_questions`) and each step with its mark or drawing. It shows for the author and for members it's shared with. Empty outline parts stay hidden as today |

### The `meeting_helper` layout

- Full screen, no sidebar: a header with "Back to Aglowy" (an icon link to Home with `aria-label`), the step dots (decorative, with visually hidden "Part 2 of 8: Treasures From God's Word"), and the meeting's name.
- `<body data-color-mode="dark" data-light-theme="light" data-dark-theme="dark">`: always dark in KIDS-01. A bright screen glows in a meeting hall.
- `lang`, `<main>` and landmarks as everywhere. The page title is "Today's meeting".
- Sizes (base-size primitives): prompt 46px type, mark and draw buttons at least 96px tall, Back and Next at least 72px, colour swatches 60px. Use Primer `Button` with a BEM modifier for the large size, and other BEM classes in `app/assets/stylesheets/components/_meeting_helper.scss`, built only from primitives.
- No sounds, no CSS transitions or animations, no counters.

### Drawing

- A `<canvas>` with a Stimulus controller (`meeting_helper/drawing_controller.js`): pointer events (`pointerdown`, `pointermove`, `pointerup`, `pointercancel`) with `setPointerCapture`, and `touch-action: none` so the tablet doesn't scroll.
- Draw at a fixed 1116×470 logical size, scaled by `devicePixelRatio`. Strokes are 9px round in the picked colour on the dark paper colour.
- Undo pops the last stroke and redraws; Start over clears.
- "All done": `canvas.toBlob("image/png")`, put the file into the form's hidden file input with `DataTransfer`, and submit. The form is a Primer form class with that file input inside, the same pattern as the file drop zone.
- The canvas has `role="img"` and `aria-label="Drawing space. Draw with your finger."`. Drawing is optional; everything else works from the keyboard.

## CLAUDE.md change in this design PR

Add a **third approved exception** to Forms and to the Primer rule: the meeting helper's child screens (large touch targets in BEM Sass from primitives) and its drawing canvas (Stimulus). Primer has neither. Both still use Primer `Button` and a Primer form wherever a button or form appears.

## Traps

1. **The note comes from `Current.user`.** `Current.user.meeting_notes.find(params[:meeting_note_id])`, so anyone else's note is a 404, including on the drawing image route, which also allows members the note is shared with (reuse `MeetingNotePolicy#show?`).
2. **A step key that isn't in the note's kind is a 404**, never a 500 (`HelperSteps.for(kind).fetch(key)` raising `ActiveRecord::RecordNotFound`).
3. **The week comes from `Current.membership.this_week`,** which respects the person's or household's time zone. `start_meeting_note` finds or creates on the unique index, so a double tap can't make two notes.
4. **Turning the helper off deletes nothing** of the children's. Turning it on twice at once makes one row (`create_or_find_by!`, unique index).
5. **The policy needs both** a child membership and the household's helper. A child whose role changes to adult loses Today's meeting, but keeps their notes.
6. **Validate drawings on the server:** content type `image/png` from the blob's analysis, not the request header, and at most 2 MB. A bad file is a validation error, not a 500.
7. **Never render `url_for(drawing.image)`** in a page; always the authorizing `drawing` route (gotcha 22).
8. **Household settings opens to adults** for the Children section only. `HouseholdPolicy#update?` (name, time zone) stays heads-only; add `HouseholdPolicy#edit?` for heads and adults, and `Household::MeetingHelperPolicy#update?` for heads and adults. The sidebar footer shows Household settings to heads and adults.
9. **No animation sneaks in.** Primer's default button transitions are fine; add nothing that moves on its own.

## States each story checks

- Helper off: no card, no sidebar item, Today's meeting 404s for a child.
- Helper on: the child sees the card and the item; a head or adult still gets a 404 on Today's meeting.
- Each step for midweek and weekend; first-step Back to the picker; last-step Finish to the summary.
- Marked and unmarked; drawn and not drawn; drawing again replaces the old one.
- A summary before and after "Show my family".
- The shared note read by a head: questions and drawings shown; the drawing image route works for them and 404s for someone outside the household.
- A child who left the household: their shares end, as for every note.
