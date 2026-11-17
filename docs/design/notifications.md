# Notifications

Aglowy tells a person when something needs them or concerns them. Every notification goes to an inbox in the app. People can also choose to get it by email or on their phone. Stories live under the **NOTIFY-01** epic. Later alerts, such as reminders for personal times, are small stories that add a kind.

Frames in `docs/design/notifications/` (README there). Mockups are in the "Notifications" row on the design canvas.

## Decisions (Casey, 17 Nov)

- **Three channels:** the inbox in Aglowy, email, and phone or browser push.
- **Email is off for everything until a person turns it on.** So is push. The inbox is always on.
- **Each kind decides when its email goes out.** Time-bound kinds email right away. The rest wait for a daily summary.
- **The first four kinds:** the weekly household preview, a family study that needs a topic, something shared with you, and an invitation not accepted.

What follows from these, approved by merging this design PR:
- **The `web-push` gem** and VAPID keys in credentials, for push. This turns on Rails' PWA manifest and service worker, which the app already has but leaves switched off.
- **The inbox's unread counter updates live** over Solid Cable (a Turbo Stream per person).

## Guardrails

- **No tracking.** No open or click tracking in emails: no pixels, no rewritten links, and SES's open and click tracking stay off. A `Notification::Reading` exists only to show what's unread.
- **No streaks or "you missed it" messages,** now or in later kinds (`docs/design/goals.md`).
- **Children never get email,** even if their login has an email address. They get the inbox and, if they turn it on, push.
- **No personal text leaves Aglowy.** Emails and push messages carry titles, dates and names, never the text of a note, a study or a goal's steps. Push goes through Apple's and Google's push services, encrypted end to end (RFC 8291).
- **Username-only logins have no email** (`docs/design/invitations.md`, Traps). Code that emails skips them.

## The kinds

`Notification::Kind` (a PORO in `app/models/notification/`) holds the list. Each kind has its wording, who gets it, its target, its icon, and when its email goes out.

| Kind | Who gets it | Made when | Subject | Says | Opens | Email |
| --- | --- | --- | --- | --- | --- | --- |
| `weekly_preview` | Every active member of the household, children too | Sunday at 6 PM in the household's zone | `Household`, with `data: { week_of: }` | "Your week in Rivera household", then "2 meetings · family study Tuesday · the circuit overseer visits from Tuesday" | That week on the calendar | Right away, as its own email listing the week |
| `study_topic_needed` | The household's heads | Each day at 8 AM in the household's zone, for sessions 3 days ahead that aren't cancelled and have no topic | `FamilyStudy::Session` | "Tuesday's family study has no topic yet", then "Choose a topic, or draft one with AI, before Tuesday, November 24." | The session | Right away |
| `shared_with_you` | Every active member of the household except the person sharing | When `Shareable#share_with` creates a sharing (meeting notes and goals) | `MeetingNote` or `Goal`, with `actor` | "Daniel shared a meeting note", then "Life and Ministry · week of November 16" | The shared note or goal | Daily summary |
| `invitation_unaccepted` | Whoever sent the invitation | Each day, for household invitations sent 5 days ago that are still pending and unexpired | `Invitation` | "Your invitation hasn't been accepted", then "Grandpa Luis (grandpa@example.com) was invited 5 days ago. Send it again?" | Members, where it can be sent again | Daily summary |

- **The wording is worked out when it's shown,** from the kind and the subject, so a renamed household or person shows the new name. Nothing personal is stored on the notification.
- **The weekly preview** is built from `Household::Calendar` for the coming Monday to Sunday: meetings, sessions and household events, never anyone's personal times. A week with nothing in it sends nothing.
- **A shared goal's title** shows in the notification. A goal's title is visible to the household once it's shared, but its steps never appear in a notification.
- **"Daily summary" kinds still push right away,** because a push is one line and easy to ignore. Only their email waits.

## Models

### `Notification`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null, `on_delete: :cascade` | Who it's for |
| `household_id` | uuid | FK → households, not null, `on_delete: :cascade` | Which household it's from |
| `kind` | string | not null, check in the four kinds | |
| `subject_type`, `subject_id` | string, uuid | not null | What it's about |
| `actor_id` | uuid | FK → users, nullable, `on_delete: :nullify` | Who did it (`shared_with_you`) |
| `data` | jsonb | not null, default `{}` | Small facts such as `week_of`. Never personal text |
| `dedupe_key` | string | not null; unique with `user_id` | So a job that runs twice makes one notification: `"weekly_preview:<household>:<week_of>"`, `"study_topic_needed:<session>"`, `"shared_with_you:<sharing>"`, `"invitation_unaccepted:<invitation>"` |
| `created_at` | datetime | not null | |

- **`user.notify(kind:, household:, subject:, actor: nil, data: {}, dedupe_key:)`** creates with `create_or_find_by!` on (`user_id`, `dedupe_key`), then calls `notification.deliver_later`. That's the only way notifications are made.
- **`belongs_to :subject, polymorphic: true`.** Each subject (`Household`, `FamilyStudy::Session`, `MeetingNote`, `Goal`, `Invitation`) gets `has_many :notifications, as: :subject, dependent: :delete_all`, so a deleted note or a cancelled invitation takes its notifications with it.
- **`Notification.visible`**: notifications from households where the person is still an active member. Someone who leaves stops seeing that household's notifications.
- **Kept for 90 days.** `Notification::PurgeJob` deletes older ones daily. Their readings and deliveries go with them (`on_delete: :cascade`).
- `preloaded`: `includes(:subject, :actor, :household, :reading)`.
- **`notification.target_path`**: where it opens, always under the notification's own household. That can be a different household from the page it's opened on.

### `Notification::Reading`

State as a record (CLAUDE.md). `notification_id`, unique, `on_delete: :cascade`.
- `notification.read` (`create_or_find_by!`); `user.read_all_notifications`, a single `insert_all` for every unread visible notification.
- `Notification.unread` is `where.missing(:reading)`.

### `Notification::Delivery`

A record that it went out on a channel: `notification_id`, `channel` (check in `email`, `push`), unique together, `on_delete: :cascade`. A retried job never sends twice.

### `NotificationSetting`

When it exists, that kind comes to that person on that channel. Nothing exists by default, so everything beyond the inbox starts off.

| Column | Type | Constraint |
| --- | --- | --- |
| `user_id` | uuid | FK → users, not null, `on_delete: :cascade` |
| `kind` | string | not null, check in the kinds |
| `channel` | string | not null, check in (`email`, `push`) |

Unique on (`user_id`, `kind`, `channel`).
- `user.notification_settings.change(enabled_pairs)` replaces the person's settings in one transaction.
- An email setting is ignored, and not offered, for anyone with no email address or who is a child in any of their active households.

### `PushSubscription`

One per browser or phone the person turned on.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid | FK → users, not null, `on_delete: :cascade` | |
| `endpoint` | string | not null, unique; `encrypts deterministic: true` | The push service URL, which works as a secret |
| `p256dh_key`, `auth_key` | string | not null; encrypted | The browser's keys |
| `label` | string | not null, up to 80 | "iPhone · Aglowy on the Home Screen", "Chrome on Mac", from the user agent and whether it runs from the Home Screen |
| `last_used_at` | datetime | nullable | Shown under the label |

A push that comes back `404` or `410` deletes the subscription (`WebPush::ExpiredSubscription`, `WebPush::InvalidSubscription`).

### `User`

- `quiet_hours_start` and `quiet_hours_end`: `time`, not null, defaults 21:00 and 07:00, on the half hour. They're read in `User#calendar_time_zone` (`docs/design/calendar.md`).
- `user.quiet_now?` and `user.quiet_hours_end_after(time)`.

## Delivery

`Notification::DeliveryJob` (`notification.deliver_later`):
1. **Push:** when the person has a push setting for the kind and at least one subscription. During quiet hours the job reschedules itself (`set(wait_until: user.quiet_hours_end_after(Time.current))`). Otherwise it sends to every subscription with `WebPush.payload_send` (TTL one day, urgency `normal`) and records a `push` delivery. The payload is `{ title: "Aglowy", body: <the one-line wording>, url: notification_path(...), tag: notification.id }`.
2. **Email right away:** for the weekly preview and the topic nudge, when the person has an email setting and can get email. It also waits out quiet hours. `NotificationMailer.notification(notification).deliver_now`, then an `email` delivery.
3. **Summary kinds** stop here. `Notification::DailySummaryJob` runs every hour. For each person whose quiet hours ended in that hour, it gathers their visible notifications from the last 24 hours that have an email setting, are summary kinds and have no `email` delivery. It sends one `NotificationMailer.daily_summary(user, notifications)` and records a delivery for each. With nothing to send, it sends nothing.

Read notifications still go in the summary: the summary is a record of what happened, and reading it in the app doesn't mean the email was unwanted.

### Recurring jobs (`config/recurring.yml`, production)

| Job | Schedule | Does |
| --- | --- | --- |
| `Notification::WeeklyPreviewJob` | every hour at minute 5 | Each household where it's Sunday and the 6 PM hour: `household.send_weekly_preview` |
| `Notification::StudyTopicJob` | every hour at minute 10 | Each household where it's the 8 AM hour: the sessions 3 days out with no topic, to its heads |
| `Notification::InvitationFollowUpJob` | every day at 2pm | Pending household invitations sent 5 days ago, to whoever sent them |
| `Notification::DailySummaryJob` | every hour at minute 15 | As above |
| `Notification::PurgeJob` | every day at 4:45am | Deletes notifications older than 90 days |

Every job is safe to run twice, through the `dedupe_key` and the deliveries.

## Pages and routes

```ruby
scope "/:household_id", as: :household do
  resources :notifications, only: %i[ index show ] do       # show marks it read and opens it
    collection { resource :readings, only: :create, module: :notifications }   # Mark all as read
  end
  namespace :settings do
    resource :notifications, only: %i[ show update ]       # Settings → Notifications
    resource :quiet_hours, only: :update
  end
  resources :push_subscriptions, only: %i[ create destroy ]
end

# Outside the household scope: email links work without signing in.
resource :email_unsubscribe, only: %i[ show create ], path: "unsubscribe/:token"
get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
```

| What | Route | Frame |
| --- | --- | --- |
| The inbox | `GET /:household_id/notifications` (`?show=unread`) | `notifications.png`, `notifications-unread.png`, `notifications-dark.png` |
| Open one | `GET /:household_id/notifications/:id`: marks it read, redirects to `target_path` | |
| Mark all as read | `POST /:household_id/notifications/readings` | |
| Settings → Notifications | `GET /:household_id/settings/notifications` | `settings-notifications.png`, `settings-notifications-child.png` |
| Turn on push here / remove a device | `POST`/`DELETE /:household_id/push_subscriptions` | `settings-notifications.png` |
| Emails | `NotificationMailer` | `email-weekly-preview.png`, `email-daily-summary.png` |
| On a phone | the same pages, push on the lock screen | `phone-notifications.png`, `phone-push.png` |

Notifications are reached through `Current.user.notifications.visible`, so someone else's notification is a 404. `NotificationPolicy` allows any active member, since the scoping does the work.

### The sidebar

- **"Notifications"** (Octicon `bell`) in the sidebar footer, above Settings, for everyone. It's selected on the inbox.
- It shows a Primer `Counter` with the unread count (`99+` past 99). The link's accessible name is "Notifications, 3 unread", or just "Notifications" when there are none.
- **Live:** creating or reading a notification broadcasts a Turbo Stream that replaces the counter (`turbo_stream_from [Current.user, :notifications]` in the shell). It's the person's own stream, never a household's.
- **On a phone,** the top bar gets a bell `IconButton` with the counter, beside the menu button. The menu keeps the same footer item.

### The inbox

- **Header:** `h1` "Notifications" and "From all your households. Kept for 90 days." Then "Mark all as read" (only when something is unread) and "Notification settings".
- **"Show":** a Primer `SegmentedControl` with "Unread (3)" and "All". All is the default.
- **The list:** grouped "Today" and "Earlier", by the person's zone, newest first, paginated at 50, in Primer `BorderBox`es. Each row:
  - an unread dot
  - the kind's icon in its color: blue for the topic nudge, pink for shared, purple for the weekly preview, gray for invitations
  - the title, bold while unread and linking to it
  - the second line
  - "<household> · <time>"
  - a visually hidden "(unread)" after an unread title
- **Empty:** a Primer `Blankslate` with "You're all caught up" and "New notifications from your households show up here."

### Settings → Notifications

A section in the "You" group after Calendar (`docs/design/settings.md`). The note under the title is "What reaches you, and where. Follows you to every household."

- **What you get** (`Settings::NotificationsForm`): one Primer `check_box_group` per kind the person can get. Its legend is the kind's name, its caption says what the kind is and when its email goes ("Right away" or "In your daily summary"), and it holds two checkboxes, Email and Phone. The mockup draws this as a table; build it from Primer check box groups, not a hand-built table.
  - Heads see all four. Adults see the weekly preview and shared. A person who is a head in any household sees the topic and invitation kinds.
  - Children, and people with no email address, get no Email checkbox. The line under the box says "Children get notifications in Aglowy and on their phone, never by email," or names the email address and says when the daily summary comes.
  - "In Aglowy: always" shows as a line, not a disabled checkbox.
- **Quiet hours** (`Settings::QuietHoursForm`): From and Until, Primer selects on the half hour, then "Nothing is emailed or sent to your phone during quiet hours. It waits until they end. Times are in <zone>, your time zone in Profile."
- **Phones and browsers:**
  - "Turn on for this browser" (primary), shown when this browser supports push and isn't subscribed. A Stimulus controller (`push_subscription`) asks for permission, registers the service worker, subscribes with the VAPID public key, and posts the subscription. If permission is refused: "Your browser blocked notifications for Aglowy. Allow them in its settings, then try again."
  - The person's subscriptions, each with its label, "Added <date> · last used <date>" and "Remove".
  - The help line: "On an iPhone or iPad, add Aglowy to your Home Screen first (Share, then Add to Home Screen), open it from there, and turn notifications on." iOS allows web push only from a Home Screen app.

### Emails

`NotificationMailer`, in the existing mailer layout:
- **`notification(notification)`:** the right-away kinds. The weekly preview lists each day of the week that has something, then "Open the calendar". The topic nudge says which session and links to it.
- **`daily_summary(user, notifications)`:** "Since yesterday", one row per notification with its household, then "Open notifications".
- **Subjects:** "Your week in Rivera household: November 23 – 29", "Tuesday's family study needs a topic", "Your Aglowy summary: 2 new".
- **Footer:** "You get this because you turned on <kind> emails. Turn off this email · Notification settings". Both links work without signing in.
- **One-click unsubscribe:** the `List-Unsubscribe` and `List-Unsubscribe-Post: List-Unsubscribe=One-Click` headers (RFC 8058) point at `POST /unsubscribe/:token`. The token is `user.generate_token_for(:email_unsubscribe)` with the kind, signed and never stored. "Turn off this email" opens `GET /unsubscribe/:token`, a focused-layout page with one button, so a mail scanner that follows links can't unsubscribe anyone.
- **Text and HTML parts,** sent through SES. No images except the Aglowy mark.

### Push

- **Turn on Rails' PWA:** uncomment the routes, link the manifest in `_head`, and give the manifest Aglowy's name, colors and icons.
- **The service worker (`app/views/pwa/service-worker.js`)** handles two events:
  - `push`: `self.registration.showNotification(payload.title, { body, icon, tag, data: { url } })`
  - `notificationclick`: focus an open Aglowy window on `url`, or open one

  It caches nothing. This isn't an offline app.
- **VAPID keys:** `web_push: { public_key:, private_key:, subject: "mailto:…" }` in credentials. The public key goes into the page for the Stimulus controller.

## Elsewhere

- **`docs/design/settings.md`:** the You group gains Notifications after Calendar.
- **`docs/design/app-shell.md`:** the sidebar footer gains Notifications above Settings, and the phone top bar gains the bell.
- **`docs/design/users.md`:** the model table points here.
- **`docs/product/vision.md`:** row 7 becomes NOTIFY-01. It said "Design done", but there was no design.
- **`CLAUDE.md`:** the stack gains `web-push` and the PWA service worker.
- **Seeds** (`db/seeds/09_notifications.rb`): a few notifications of each kind for the Rivera household, some read, made through `user.notify`. Settings stay off, as for a new person.

## Traps

1. **Make notifications only through `user.notify`,** with a `dedupe_key`. Jobs run twice and shares happen twice.
2. **Read times in the right zone.** Quiet hours and the daily summary use the person's zone (`calendar_time_zone`). The weekly preview and the topic nudge use the household's.
3. **Don't email children** or username-only logins, even when they have a setting from before they became a child somewhere.
4. **No personal text in emails or push.** Titles and dates only.
5. **Never mark something read from an email or push link** except by opening it (`show`). Mail scanners follow links, and summaries aren't readings.
6. **One person's stream** for the live counter: `[user, :notifications]`, never a household stream.
7. **Delete dead subscriptions** on 404 or 410, or every push retries forever.
8. **Leaving a household** hides its notifications through `visible`. Don't delete them on leave: the person might come back, and they age out in 90 days.

## States each story checks

- Head, adult, child; someone in two households; a non-member (404 on someone else's notification)
- Unread, read, all read; none at all; more than 50
- Each kind's wording and target, including a renamed household and a deleted subject
- Settings: all off (the default), some on; a child (no email); a username-only adult (no email)
- Quiet hours: a push or email due inside them waits; the daily summary at their end; nothing to summarize
- Push: turned on, refused, removed, an expired endpoint
- Unsubscribe by link and by one-click POST; a bad or old token
- Desktop and phone; light and dark
