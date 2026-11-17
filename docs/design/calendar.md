# Calendar

One calendar per household that everyone in it can see: the congregation meetings, family studies, assemblies, conventions, the circuit overseer's visit, field service and anything else the household plans. Each person can also set their own times for Bible reading, personal study and meeting prep. Those times are private unless the person shares them. Stories live under the **CAL-01** epic.

Frames in `docs/design/calendar/` (README there). Mockups are in the "Calendar" row on the design canvas.

## Decisions (Casey, 16 Nov)

- **Everyone in the household sees the calendar,** children too.
- **Heads and adults add and edit household events.** Children don't.
- **A person's own times are private by default.** In Settings → Calendar, each person can share their times with any household they're in. Members there then see the title and time, never the notes or links behind them.
- **A private subscribe link** puts the calendar on a phone's own calendar app.
- **In the first version:**
  - Today on Home
  - marking a time done
  - children add their own times
  - meeting prep opens that week's meeting notes

## What CAL-01 builds, and what comes later

| In CAL-01 | Later |
| --- | --- |
| Week and month views, and a day-by-day list on a phone | A day view |
| Meetings (from Settings → Meetings) and family study sessions on the calendar, without copying them | Editing a meeting time for one week (a special week, the CO's visit) |
| Household events: once, weekly or monthly; all day or timed; several days long | Skipping or moving one occurrence of a repeating event |
| Personal times on chosen weekdays, with a done mark per day | Reminders in Aglowy (Notifications, vision row 7). The phone feed carries reminders already |
| Sharing your times with a household | Sharing with one person rather than a household |
| Today on Home | |
| A private `.ics` link per person, resettable | Two-way sync with Google or Apple calendars |

## Who can do what

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| See the household's calendar | yes | yes | yes |
| Add, edit and delete household events | yes | yes | no |
| Add, edit and delete their own times; mark them done | yes | yes | yes |
| Share their own times with a household they're in | yes | yes | yes |
| See another member's shared times | yes | yes | yes |
| Their own subscribe link | yes | yes | yes |

- Household events are reached through `Current.household`, so another household's event is a 404.
- Personal times are reached through `Current.user`, so another person's time is a 404, even one shared with you. A shared time only appears on the calendar. It has no page of its own.
- Meetings come from Settings → Meetings, and family studies from Family studies. The calendar only shows them, and links to them.

## What's on the calendar

Each item has a kind, and each kind has a color. The left column's "Show" checkboxes group them:

| Show | Kinds | Comes from | Color (Primer display primitives) |
| --- | --- | --- | --- |
| Meetings | midweek, weekend | `Household#meetings_between` (from the household's meeting times) | red |
| Family studies | each session | `FamilyStudy::Session` (not cancelled) | blue |
| Assemblies and special events | circuit assembly, regional convention, circuit overseer's visit, Memorial | `Household::Event` | purple |
| Field service | field service | `Household::Event` | green |
| Other events | other | `Household::Event` | gray |
| My times | the person's own | `PersonalTime` | orange |
| "<Name>'s times", one per member who shares | theirs | `PersonalTime`, shared | pink, with a dashed border |

Each kind uses the `--display-<color>-bgColor-muted`, `--display-<color>-borderColor-emphasis` and `--display-<color>-fgColor` primitives, in BEM Sass (`.calendar-item--meeting`, …), so dark mode comes from Primer (frame `calendar-dark.png`). Color is never the only cue: every item says what it is in its title.

## Models

### `Household::Event`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, not null | |
| `kind` | string | not null, check in (`circuit_assembly`, `regional_convention`, `co_visit`, `memorial`, `field_service`, `other`) | Picks the color and the Show group |
| `title` | string | not null, up to 80 | Prefilled from the kind ("Circuit assembly"), editable |
| `starts_on` | date | not null | The first day |
| `days` | smallint | not null, default 1, check between 1 and 14 | A circuit overseer's visit runs 6 days, a convention 3 |
| `time_of_day` | time | nullable | Null means all day. Local to the household's zone, like `FamilyStudy` (gotcha 14) |
| `duration_minutes` | integer | nullable; check > 0 and at most 720 | Required when `time_of_day` is set, null when it isn't (check constraint) |
| `frequency` | string | not null, default `once`, check in (`once`, `weekly`, `monthly`) | |
| `interval` | integer | not null, default 1, check > 0 | |
| `week_of_month` | smallint | check in (1, 2, 3, 4, 5, -1); required when `monthly` (check constraint) | The same rule as family studies |
| `repeats_until` | date | nullable | Open-ended when null. No UI in CAL-01 |
| `location` | string | nullable, up to 120 | "Where" |
| `note` | string | nullable, up to 500, encrypted | Household text, like a study's notes |
| `created_by_id` | uuid | FK → users, not null | |

- **Several days only when it's all day and doesn't repeat:** a check makes `days = 1 OR (time_of_day IS NULL AND frequency = 'once')`.
- **Occurrences are worked out, not stored.** `event.occurrences_between(range)` returns each occurrence's start and end. There are no per-occurrence rows, so nothing needs topping up the way family study sessions do. Editing an event changes every occurrence.
- **Recurrence is shared with family studies.** Move `FamilyStudy::Recurrence` to `Recurrence` (`app/models/recurrence.rb`), taking `frequency:`, `interval:`, `starts_on:`, `ends_on:` and `week_of_month:` as keywords. `FamilyStudy#recurrence` and `Household::Event#recurrence` each pass their own columns. Its tests move with it, unchanged.
- **Times are built in the household's zone** with `zone.local(…)`, never by adding days to a UTC time (family-studies gotcha 14).
- `Household` gets `has_many :events, class_name: "Household::Event", dependent: :delete_all`.
- Scope: `preloaded` (`includes(:created_by)`).

### `PersonalTime`

A time a person sets aside on some weekdays.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null | Personal; follows the person between households |
| `kind` | string | not null, check in (`bible_reading`, `personal_study`, `meeting_prep`, `other`) | "What for" |
| `title` | string | not null, up to 80, encrypted | Prefilled from the kind ("Daily Bible reading"), editable. Personal text (`docs/product/vision.md`, Private by default) |
| `wdays` | smallint[] | not null; check `cardinality(wdays) BETWEEN 1 AND 7 AND wdays <@ '{0,1,2,3,4,5,6}'` | Sunday is 0, like Ruby's `wday` |
| `time_of_day` | time | not null | Local to the person's own zone (below) |
| `duration_minutes` | integer | not null, default 30, check between 5 and 240 | "For" |
| `starts_on` | date | not null, default today | Earlier weeks don't show a time that didn't exist yet |
| `opens_type`, `opens_id` | string, uuid | nullable together; check `opens_type` in (`PersonalStudy`, `PersonalNote`) | What a study time opens |

- **The person's own zone:** `User#calendar_time_zone`, which is `users.time_zone` (Settings → Profile), or when that's blank the zone of the person's first active household by name (the same household `/account` sends them to, `docs/design/settings.md`). One rule for every household page, Today on Home and the phone feed, so a time is the same instant everywhere. Each occurrence is `zone.local(date…, time_of_day…)`, so 6:30 AM stays 6:30 AM across a DST change.
- **What it opens:**
  - `meeting_prep` opens the person's meeting note for the next meeting after it that week, through the existing `POST /:household_id/meeting_notes` (`kind`, `week_of`), which finds or creates it (`docs/design/meeting-notes.md`). A prep time on a Thursday before a Friday midweek meeting opens that week's Life and Ministry note. A prep time with no meeting after it that week (or with no meeting times set) opens nothing. Nothing is stored for this.
  - `personal_study` and `other` can open one of the person's own studies or notes (`opens`). Looked up through `Current.user`, so someone else's study can't be picked (validation).
  - `bible_reading` opens nothing.
- `belongs_to :opens, polymorphic: true, optional: true`. `PersonalStudy` and `PersonalNote` each get `has_many :personal_times, as: :opens, dependent: :nullify`.
- At most 30 times per person (validation).
- `user.personal_times.occurring_between(range)` returns each occurrence (`PersonalTime::Occurrence`, a PORO with the time, the date in the person's zone and whether it's done).

### `PersonalTime::Completion`

A done mark for one day. State as a record, not a boolean (CLAUDE.md).

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `personal_time_id` | uuid | FK → personal_times, not null, `on_delete: :cascade` | |
| `on` | date | not null; unique with `personal_time_id` | The day it was done, in the person's zone |

- `personal_time.complete(on:)` uses `create_or_find_by!`, so a double tap makes one row. `personal_time.uncomplete(on:)` deletes it.
- **Only today or an earlier day,** and only a day the time falls on (validation). The calendar shows no done box on a future day.
- **No streaks** (`docs/design/goals.md`). Never show "5 days in a row" or a missed-days count. A done mark is a tick and nothing more.
- Done marks are never shown to anyone else, even when the time is shared.

### `Membership::TimeSharing`

When it exists, the person's times show on that household's calendar. State as a record.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `membership_id` | uuid | FK → memberships, not null, unique, `on_delete: :cascade` | The person, in that household |

- `membership.share_times` (`create_or_find_by!`), `membership.stop_sharing_times`, `membership.shares_times?`.
- Only active memberships count: `Household#members_sharing_times` joins `memberships.active`. Someone who leaves stops appearing, and their row stays harmless.
- **What others see:** the kind's color with a dashed border, the time, and "<First name>'s time" under the title. The title is shown as-is; the person chose to share it. Never the done mark, never what it opens, never a link.

### `CalendarFeed`

A person's private subscribe link.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null, unique | One link per person |
| `token` | string | not null, unique; `has_secure_token`, `encrypts :token, deterministic: true` | Found by the token, and still not readable in a database dump |

- `user.calendar_feed` is created the first time Settings → Calendar shows it (`create_or_find_by!`).
- `calendar_feed.reset` calls `regenerate_token`. The old link stops working at once.

## How a calendar is put together

`Household::Calendar.new(household, viewer: Current.user, range:)`, a PORO in `app/models/household/`, gathers every item in the range as `Household::Calendar::Item`s: kind, title, subtitle, start, end, whether it's all day, an href (or none), and for the viewer's own times, the done state.

- meetings: `household.meetings_between(range)`, built like `meeting_in` (Trap 5 in `docs/design/meeting-helper.md`)
- family studies: `FamilyStudy#occurrences_between(range)` for each of the household's studies. It returns the stored sessions in the range that aren't cancelled, and, for a repeating study, the `Recurrence` dates after its last stored session, as unsaved occurrences titled "Family study" with "Topic not chosen yet" that link to Family studies. Stored sessions only reach the generator's horizon (the later of 31 August and three months ahead, `docs/design/family-studies.md`, rule 4), and the calendar can be browsed past it and the phone feed runs 180 days ahead. Nothing is stored for the later dates; the daily task still makes their rows when the horizon reaches them.
- household events: `household.events.preloaded`, each expanded with `occurrences_between(range)`
- the viewer's own times
- other members' times, for each member in `household.members_sharing_times`, leaving out the viewer

The page asks for one week (or one month's 6 weeks) at a time, so each source is one query; occurrences are expanded in Ruby. Personal times are expanded over the person's own dates that cover the range's first and last instants (one day either side is enough), and only occurrences whose start falls inside the range are kept. A 12:30 AM Monday time in Tokyo is Sunday afternoon in Los Angeles, and still lands in the Los Angeles week.

**One clock per page.** The calendar shows everything in the household's zone, like every other household page. A personal time is converted from the person's own zone. When the viewer's zone differs from the household's, a muted line under the title says so: "Times are in Central Time, the household's time zone."

**Links:**
- a meeting opens the viewer's note for it (`POST /:household_id/meeting_notes` with `kind` and `week_of`). For a child on a meeting day with the meeting helper on, it opens Today's meeting instead (`docs/design/meeting-helper.md`, Who can do what).
- a family study opens its session page
- a household event opens its edit dialog for heads and adults; for children it isn't a link, and its location and note show under the title
- the viewer's own time opens what it opens, if anything. Its title opens its edit dialog
- a shared time isn't a link

## Pages and routes

Under `/:household_id`, so they use the household layout.

```ruby
scope "/:household_id", as: :household do
  resource :calendar, only: :show                       # ?view=week|month&date=2026-11-17&hide[]=field_service
  namespace :calendar do
    resources :events, only: %i[ new create edit update destroy ]
  end
  resources :personal_times, only: %i[ new create edit update destroy ] do
    resources :completions, only: %i[ create destroy ], module: :personal_times   # create sends on=2026-11-17; destroy's id is the date
  end
end

# Outside the household scope: the phone feed has no session.
get "calendar/:token", to: "calendar_feeds#show", as: :calendar_feed, format: :ics
```

| What | Route | Frame |
| --- | --- | --- |
| The calendar, by week (default) | `GET /:household_id/calendar` (`CalendarsController#show`) | `calendar-week.png`, `calendar-dark.png` |
| By month | `?view=month` | `calendar-month.png` |
| A child's calendar | the same page | `calendar-child.png` |
| Add or edit a household event | `Calendar::EventsController`, in a Primer `Dialog` | `calendar-new-event.png` |
| Add or edit my time | `PersonalTimesController`, in a Primer `Dialog` | `calendar-new-time.png` |
| Mark done | `POST /:household_id/personal_times/:id/completions` with `on` (the date) in the body, Turbo Stream | |
| Undo | `DELETE /:household_id/personal_times/:id/completions/:on` (the date as the id, `2026-11-17`), Turbo Stream | |
| Home | Today in the Mine column | `home-today.png` |
| Settings → Calendar | `GET /:household_id/settings/calendar` | `settings-calendar.png` |
| On a phone | the same page | `phone-calendar.png` |

### The page

- **Header:** `h1` "Calendar" and the line "Rivera household's meetings, studies and events, with your own times." On the right: "Add my time" (secondary), and "Add household event" (primary), which only heads and adults see.
- **Toolbar:** "Today", previous and next (`IconButton`s labelled "Previous week" / "Next week", or "month"), the range as an `h2` ("November 16 – 22, 2026" or "November 2026"), and a Primer `SegmentedControl` labelled "View": Week, Month. Each is a link carrying `view`, `date` and `hide`, so the URL is the whole state.
- **Left column:**
  - "Show" checkboxes in two groups, the household's name and "Times", each with its color swatch (frame `calendar-week.png`). A Primer form class (`Calendars::ShowForm`) with `method: :get`, auto-submitted by a small Stimulus controller, with a "Show" submit button inside `<noscript>`. Unchecked kinds go in `hide[]`. "<Name>'s times" has one checkbox per member who shares.
  - Under them: "Only you see your times. Share them", linking to Settings → Calendar. When the viewer shares, it reads "Your times are shared with Rivera household. Change".
  - "Add to your phone's calendar", linking to Settings → Calendar.
- **Week:** seven day columns, Monday first (meeting weeks start on Monday, `docs/design/meeting-helper.md`). Each day is a `section` with an `h3` ("Tue 17"; screen readers get "Tuesday, November 17" from a visually hidden span), today marked with `aria-current="date"`. All-day events sit in a band across the top, spanning their days. Timed items follow in order of start, each a card with the time, the title and a subtitle (a study's topic, a location, "Daniel's time"). Not a time grid: families have a handful of items a day, and a list reads better on every screen.
- **Month:** a 6 × 7 grid of days from the Monday on or before the 1st. Each day shows up to three household items as one-line chips, then "N of my times" (and "+2 more" when there are more). A day number links to that week. The circuit overseer's visit and other multi-day events run as a bar across their days.
- **My time's done box:** a checkbox labelled "Done: Daily Bible reading, Tuesday" in a one-field Primer form (`PersonalTimes::CompletionForm`), auto-submitted: unticked, it posts to `completions` with the day in a hidden `on` field; ticked, it sends `DELETE completions/<day>`. The Turbo Stream response replaces the card, and the title gets a line through it when done. No done box on future days, and none on anyone else's time.
- **Empty:** a week with nothing in it still shows its days. A household with no meeting times set, no studies and no events shows a Primer `Blankslate` above the week: "Nothing on the calendar yet." with "Set your meeting times" (heads and adults, to Settings → Meetings) and "Add household event".

### The household event dialog

A Primer `Dialog` "Add a household event" (or "Edit household event", with "Delete event" as a danger button on the left of the footer). `Calendar::EventForm`:
- Kind (select): Circuit assembly, Regional convention, Circuit overseer's visit, Memorial, Field service, Other. Choosing one prefills Title while Title hasn't been edited (Stimulus).
- Title (required, up to 80)
- All day (checkbox, checked by default for assemblies, conventions and the CO's visit)
- When all day: Starts and Ends dates (Ends from Starts to 13 days later; it sets `days`). When timed: Date, Starts and Ends times (Ends sets `duration_minutes`).
- Repeats: "Doesn't repeat", "Weekly on Saturday", "Monthly on the fourth Saturday", "Monthly on the last Saturday" (only on the last one), built from the date by the same rule as family studies (scheduling rule 5, without Daily). Hidden when Ends is a later day.
- Where (optional), Note (optional, up to 500)
- The muted line: "Everyone in Rivera household sees this. Meetings come from Settings → Meetings, and family studies from Family studies."

A refused save re-renders the dialog with the errors by the fields. A saved one closes it and refreshes the calendar (Turbo Stream replacing the week or month).

### The "my time" dialog

A Primer `Dialog` "Add my time" (or "Edit my time", with "Delete time"). `PersonalTimes::Form`:
- What for (radio group): Bible reading, Personal study, Meeting prep, Other. Prefills Title ("Daily Bible reading", "Personal study", "Meeting prep") while Title hasn't been edited.
- Title (required, up to 80)
- Days: a check box group of the seven days, laid out in a row (Primer `check_box_group`; no hand-built toggle buttons). At least one.
- At (time) and For (15, 30, 45 minutes, 1 hour, 1½ hours, 2 hours)
- Opens:
  - Meeting prep: the line "That week's Life and Ministry notes" (or "Weekend meeting notes" when the next meeting is the weekend one), with the caption "Meeting prep before a meeting opens that week's notes."
  - Personal study or Other: a select of the person's studies and notes, plus Nothing
  - Bible reading: hidden
- The muted line: "Only you see your times. You can share them with a household in Settings → Calendar." When the person already shares with this household: "Rivera household sees this time's title and when it is."

Children see the same dialog. The calendar is the only place a child's times are made.

### Today on Home

A "Today" box at the top of Home's Mine column (frame `home-today.png`), for everyone:
- header "Today" with the date
- today's items from `Household::Calendar` for today: the person's own times, with their done boxes, and the household's meetings, study sessions and events. Not other members' shared times.
- each row: the kind's color bar, the time, the title and subtitle, linking as on the calendar
- footer link "Open calendar"
- nothing today: "Nothing on your calendar today." and the footer link

The "Today's meeting" card (`docs/design/meeting-helper.md`) stays as it is; on a meeting day the meeting also appears in Today.

### Settings → Calendar

A new section in the "You" group, after Tags and collections (`docs/design/settings.md`). Note under the title: "Who sees your times, and your phone calendar link." Frame `settings-calendar.png`. Every role sees it.

```ruby
namespace :settings do
  resource :calendar, only: :show
  resource :time_sharing, only: :update        # the checkboxes
  resource :calendar_feed, only: :update        # Reset link
end
```

- **Share my times** (a `BorderBox`): "Your Bible reading, study and meeting prep times are private. Members of a household you pick here see them on its calendar: the title and time, never your notes or links." Then a check box group, one per active household the person is in (`Settings::TimeSharingForm`), and Save. Saving calls `share_times` or `stop_sharing_times` on each membership and returns with "Sharing saved."
- **Add to your phone's calendar** (a `BorderBox`): "Subscribe to this link in your phone's calendar app to see your households' events and your own times there, with reminders for your times. Anyone with the link can see them, so keep it to yourself." Then "Your private link": a read-only Primer `TextField` holding the `webcal://` URL, a Primer `ClipboardCopyButton` ("Copy"), the caption "Your phone checks it every few hours. It includes everyone's household events and only your own times.", and "Reset link" (danger, in a confirm `Dialog`: "Your old link stops working. Subscribe again on each device with the new one.").

### The phone feed

`GET /calendar/:token.ics` (`CalendarFeedsController#show`):
- no session: it skips `authenticate_identity!` and `verify_authorized`; the token is the authorization. An unknown token is a 404.
- `rate_limit to: 30, within: 1.minute`, and `Cache-Control: private, max-age=900`
- content: for every active household the person is in, its meetings, family study sessions and events; and the person's own times. Never anyone else's times. From 30 days back to 180 days ahead.
- `CalendarFeed::Document`, a PORO, writes RFC 5545 by hand (no gem): one `VEVENT` per occurrence with a stable `UID` (`<kind>-<source id>-<date>@aglowy`). The kind is `event`, `time`, `meeting` or `study`, so two kinds of item never share a UID. The source id is the event's or the personal time's id, `<household id>-midweek` or `-weekend` for a meeting, and the study's id for a family study, both before and after the daily task stores its session. The date is the occurrence's slot date (a session's `recurrence_at`, in the household's zone), so a moved session or a newly stored one keeps its UID. Then `DTSTAMP`, `DTSTART`/`DTEND` in UTC (or `VALUE=DATE` for all day), `SUMMARY` and `LOCATION`. The household's name goes in each household item's summary ("Midweek meeting · Rivera household"). Escape `\`, `;`, `,` and newlines; fold lines at 75 octets; end lines with CRLF.
- each of the person's own times gets a `VALARM` (`ACTION:DISPLAY`, `TRIGGER:PT0M`, and the `DESCRIPTION` RFC 5545 requires on a display alarm, which is the same text as the event's `SUMMARY`), so the phone reminds them when it starts.
- **No notes and no links in the feed.** No `DESCRIPTION` on any `VEVENT` and no `URL`: a feed link can leak, so it carries titles, times and places only. The alarm's `DESCRIPTION` repeats the title and nothing more.
- `webcal://` in Settings is the same URL with `webcal` in place of `https`.

### On a phone

Below Primer's `md` breakpoint (frame `phone-calendar.png`):
- the week becomes a list, one day after another, each with its date as a heading ("Today · Tuesday, November 17"); multi-day events show once, as a band above the list
- the header's two buttons become one Primer `ActionMenu` "Add", with "Add my time" and "Add household event" (heads and adults)
- the Show checkboxes move into a `Dialog` opened by an `IconButton` labelled "Show on the calendar"
- the month view isn't offered; `?view=month` on a phone shows that month's weeks as the list
- every target is at least 44 px

## Elsewhere

- **Sidebar:** "Calendar" (Octicon `calendar`) in the Household group, after Home (`docs/design/app-shell.md`).
- **Family studies:** sessions show on the calendar as they are. Nothing about `FamilyStudy` changes except moving `Recurrence`.
- **Settings → Meetings:** saving meeting times changes the calendar at once, since meetings are worked out from them.
- **Seeds:** each story that adds something people see adds it to `db/seeds/` (CLAUDE.md): the Rivera household's CO visit, circuit assembly, Saturday field service and Kingdom Hall cleaning; Maria's Bible reading, study and meeting prep times with some done; Daniel's own time, shared with the household.

## Traps

1. **Never add days to a UTC time.** Every occurrence, of an event or a personal time, is built with `zone.local` from a local date and time (family-studies gotcha 14).
2. **Two zones meet here.** Events and meetings are in the household's zone; personal times are in the person's. Convert both to the household's zone to draw the page, and date a done mark in the person's zone.
3. **A shared time is not a shared record.** Show it on the calendar only. No page, no link, no done mark, nothing it opens. Its policy is still owner-only.
4. **Children never get the event form,** and hiding the button isn't authorization: `Household::EventPolicy#create?` is head or adult.
5. **The feed has no session.** Look up only by the token, show only that person's view, and never put notes or links in it.
6. **Don't store occurrences** of events or personal times. Expand them for the range asked for. Family study sessions stay rows, as they are.
7. **Encrypted titles can't be searched in SQL.** There's no calendar search in CAL-01; don't add one that reads `personal_times.title`.
8. **No streaks.** A done mark is a tick on one day. Never count runs or missed days.

## States each story checks

- Head, adult, child; a non-member (404); another household's event or another person's time (404)
- A week with nothing; a week with every kind; a multi-day event across two weeks; a monthly event on a fifth weekday
- Meeting times not set; set; a week when daylight saving time changes
- A personal time on a future day (no done box), today (done and not done), a past day
- Times not shared, shared with this household, shared with another household only; a member who left
- The viewer's zone the same as the household's, and different
- The feed: a good token, an unknown token, after Reset
- Desktop and phone; light and dark
