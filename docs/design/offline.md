# Offline

Aglowy on a phone with no connection: at the Kingdom Hall, in the ministry, first thing in the morning, at a family study. The pages a person needs are kept on their own device, so they can read them and write notes without a connection. Notes written offline save to Aglowy by themselves when the connection comes back.

It builds on `docs/design/notifications.md` (the service worker and the PWA manifest), `docs/design/settings.md` (a section per setting), `docs/design/meeting-notes.md` and `docs/design/notes.md` (the two notes it can write offline).

Frames in `docs/design/offline/` (README there). Mockups are in the "Offline" row on the design canvas.

## Decisions (Casey, 18 Nov)

- **Read, and write notes.** Pages kept on the device stay readable offline. Meeting notes and Notes can be written offline and save when the connection is back. Nothing else changes offline.
- **For the meeting, the ministry, the morning and family study.** What's kept is chosen for those four.
- **Per device, and opt in.** Off by default. Each person turns on "Keep available offline" on each phone or computer in Settings.

This replaces "It caches nothing. This isn't an offline app." in `docs/design/notifications.md`.

What follows from these, and needs Casey's OK in the PR:

- **Your words are kept on the device as they are.** On the server, personal text is encrypted. A browser's offline storage isn't, beyond the phone's own lock. Turning it on says so in plain words, and asks the person to use it only on their own device.
- **Signing out removes everything** Aglowy kept on the device. Notes still waiting to save are named first, with "Stay signed in". A different person signing in on the same device also removes the first person's copy.
- **Anyone signed in can turn it on,** children included, on their own device. A head can't turn it on or off for someone else.
- **Nothing on the server records that it's on.** The switch lives in the browser. The server can't tell which devices keep a copy, so Settings can only show this device.
- **Starting today's meeting note needs a connection.** If the person's note for the meeting doesn't exist yet when they go offline, Today's meeting offers a new Note instead, which can be written offline. Their meeting note can be started once they're back online.
- **When a note changed on another device while you were offline, yours doesn't save over it.** What you wrote offline is kept on the device beside the note, to copy from or discard. Aglowy never merges the two.
- **Updating the copy fetches up to 150 pages,** at most once an hour while Aglowy is open on that device, and on "Update now".

## What OFFLINE-01 builds, and what comes later

| In OFFLINE-01 | Later |
| --- | --- |
| Settings → Offline, per device | Choosing which areas to keep |
| Pages kept when opened; a set kept fresh while online | jw.org and wol.jw.org pages offline (their terms: Aglowy never fetches them) |
| An offline banner, and a page for what isn't kept | Starting today's meeting note offline |
| Writing meeting notes and Notes offline, saved when back online | Meeting helper marks and drawings offline |
| A new Note offline | Goals, calendar marks, bookmarks and plans offline |
| A note changed on another device: yours kept beside it | Merging two versions of a note |
| Removing the copy on sign out | Hotwire Native |

## How it works

Turbo has no released offline support (8.0.23, the latest, has none; `hotwired/turbo#1427` is unmerged). Aglowy's own service worker does it, small and hand-written, with the same three ideas as that PR: a list of rules, network first for pages, cache first for assets.

### Turning it on: Settings → Offline

A section in the You group, after Notifications, for everyone (frames `offline-settings-off.png`, `offline-settings-on.png`). `GET /:household_id/settings/offline` (`Settings::OfflinesController#show`, authorized for any member, as Appearance is).

- **Off:** what it does, the plain warning (Decisions), and "Keep available offline on this device".
- **On:** "On for this browser · Chrome on Mac", when it was last updated, how many pages and how much space, "Update now" and "Turn off and remove".
- **What's kept:** the list in What's kept, below.
- **Waiting to save** (when on): each note written offline that hasn't saved, with its title and when it was written, and "Open" for one that couldn't save (Writing notes offline).

The page's buttons are not a form: the state lives in the browser, so the `offline` Stimulus controller handles them and nothing is posted. "Keep available offline" registers the service worker (`/service-worker`, scope `/`, as push does), asks for persistent storage (`navigator.storage.persist()`), stores `{ enabled: true, identity: <id> }` in IndexedDB (`aglowy-offline`, store `settings`), and starts an update. "Turn off and remove" deletes Aglowy's caches and the `aglowy-offline` database. When notes are waiting to save, it names them and asks first, as signing out does.

The service worker stays registered for push either way. With offline off, it handles no `fetch` events, exactly as today.

### What's kept

Pages are kept only when the server marks them: a controller concern, `OfflineKeepable`, adds `keep_offline` as an `after_action` that sets the response header `Aglowy-Offline: keep` on a successful HTML GET. The service worker stores nothing without it. The concern is included in:

| Area | Controller actions | Fresh while online (the kit) |
| --- | --- | --- |
| Today's meeting | `todays_meetings#show` | yes |
| Meeting notes | `meeting_notes#index`, `#show`, `#edit`; the helper's `steps#show`, `summaries#show` | the list; the person's notes from the last 14 days and the next 7, show and edit |
| Meeting parts | `meeting_parts#index`, `#show` | the person's upcoming parts |
| Notes | `personal_notes#index`, `#new`, `#show` | the list, New note, the 50 newest and every pinned note |
| Bookmarks | `bookmarks#index` | yes |
| Daily brief | the brief's page, once BRIEF-01 builds it | today's brief |
| Family study | `family_studies/sessions#show` | the household's next session |
| Offline | `offlines#show`, HTML only (below) | yes |

Never kept, with no header: Settings, sign in and invitations, Madmin, AI requests and their progress, drawings' images, anything that isn't a full HTML page (Turbo Frame requests, Turbo Streams, JSON).

Pages from these areas that the person opens are kept too, for 14 days from their last update.

### The kit: keeping it fresh

`GET /:household_id/offline.txt` (`OfflinesController#show`, `format.text`; the same action's HTML is the offline page, below) answers with one path per line, from `Offline::Kit.new(user: Current.user, household: Current.household).paths`, at most 150. It's a list of the person's own URLs, nothing else: no titles, no text.

While Aglowy is open, online and turned on, the `offline` controller asks the service worker to update at most once an hour, on turning on, and on "Update now". The service worker fetches the list, then each path one at a time with the request header `Aglowy-Offline: refresh`, and stores the ones that come back marked. It removes kept pages more than 14 days old and kit pages that dropped off the list.

**A refresh is not a visit.** `Current.offline_refresh` (a new `Current` attribute, set by `ApplicationController` from the request) is true for a request with `Aglowy-Offline: refresh`. Nothing that records a visit runs on one: the daily brief's `mark_seen` on its page and on the Home card, and anything else that marks something read or opened. A refresh never creates anything either; Today's meeting's `show` already doesn't.

### The service worker

`app/views/pwa/service-worker.js` gains a `fetch` handler. It does nothing unless `settings.enabled` is true and `settings.identity` is set.

- **Assets** (`/assets/*`, fingerprinted): cache first, in `aglowy-assets`. A page opened online stores its assets as the browser asks for them. A kit page that was never opened has its HTML fetched by an update but not its assets, so **an update also stores every `/assets/` URL named in each page it keeps** (the `href` and `src` values starting `/assets/`, matched in the HTML text) that isn't stored yet. After a deploy, refreshed pages name the new fingerprints and the same update stores them. At the end of an update, assets no kept page names any more are deleted.
- **Pages** (same-origin GET navigations and Turbo visits that accept `text/html`, no `Turbo-Frame` header): network first, with a 4 second wait before falling back to the kept copy. A response marked `Aglowy-Offline: keep` is stored in `aglowy-pages-<identity>`, with the time it was stored.
- **A redirect is kept as a redirect.** `todays_meetings#show` redirects to the note when there is one. The worker stores a `Response.redirect` to the final URL under the first URL, and the final page under its own, because a navigation can't be answered with a followed redirect.
- **Not kept and offline:** a navigation inside `/:household_id/` gets that household's kept `/:household_id/offline` page; any other gets a plain built-in page.
- **Anything else** goes to the network untouched: POST, PATCH and DELETE, other origins, and every request when offline mode is off.

The worker serves only from the cache of the identity it was last told. The layout puts `<meta name="aglowy-identity" content="<identity id>">` on signed-in pages, and the `offline` controller (on `<body>`, every layout) sends it to the worker on each page load.

### The banner

The household and focused layouts put `<meta name="aglowy-rendered-at" content="<ISO time>">` and `<meta name="aglowy-from-kept-copy" content="no">` in the head. When the worker answers a page from the kept copy, it changes that meta's `content` to `yes` in the HTML it serves (one text replacement), so the page knows, even when the phone thinks it's online and the server was simply slow to answer. The `offline` controller shows a Primer `Banner` (`scheme: :warning`) at the top of the page while `navigator.onLine` is false or the page came from the kept copy: "You're offline. Showing what this phone saved at 7:02 AM.", with the rendered-at time in the person's own time zone (frame `phone-offline-meeting.png`). It goes away on the `online` event when the page is fresh, and on the next page that comes from the network, whose meta says `no`. The header shows an "Offline" Label while it's showing.

A link to something that needs the network (jw.org, wol.jw.org) stays a link; it simply fails, as it would anywhere.

### The offline page

`GET /:household_id/offline` (`OfflinesController#show`, `format.html`, household layout, kept and in the kit): "This page isn't saved on this phone. It opens when you're back online. These are:" and a link to each area in What's kept, for this household (frame `phone-offline-missing.png`). Every member can open it; it shows nothing personal.

## Writing notes offline

Three forms: a meeting note's edit (`meeting_notes#update`), a note's page (`personal_notes#update`) and New note (`personal_notes#create`). Each gets the `offline-form` Stimulus controller.

- **Offline, the button reads "Save on this phone".** On submit while `navigator.onLine` is false, or when Turbo's request fails for want of a network (`turbo:fetch-request-error`), the controller stops the submit and stores the form's fields in IndexedDB (store `waiting`): `{ id, identity, url, method, fields, title, base, written_at, state: "waiting" }`. Lexxy keeps the body in its hidden input, so `FormData` holds it. "Saved on this phone at 10:41 AM" shows beside the button (frame `phone-offline-note.png`).
- **One waiting save per form, each save its own revision.** Each save on the phone gets a new `revision` (a UUID made on the device). Saving the same note again replaces the waiting save's fields and `revision`, keeping its first `base`.
- **While a save is being sent** its state is `sending`, with the `revision` that was sent. Saving again on the phone meanwhile stores the new fields with a new `revision` and `state: "waiting"`.
- **The scripture picker needs a connection.** Offline, its button is disabled with "The picker needs a connection. Typed references like Ps. 46:1 still link when the note saves." References typed by hand link on save, as today.
- **Back online, it saves by itself.** On every page load while online, and on the `online` event, the `offline` controller sends each waiting save, oldest first, with `fetch`: the stored fields, the page's current CSRF token (`X-CSRF-Token`), `Accept: text/html` and the header `Aglowy-Offline-Replay: <revision>`.
- **Saved means the server says so.** A replay that saves answers `200` (not a redirect) with the header `Aglowy-Offline-Saved: <the record's new updated_at>`, and for a new Note, `Location: <its URL>`. `OfflineReplayable` does this for any request with `Aglowy-Offline-Replay`. Anything without that header is not a save, whatever its status: a signed-out replay is redirected to sign in like any other request, `fetch` follows it to the sign-in page, and the save stays `waiting` for when that person signs in again.
  - `Aglowy-Offline-Saved`: in one IndexedDB transaction, the save is deleted only if it still holds the `revision` that was sent. If it holds a newer one, it stays `waiting` and its `base` becomes the `Aglowy-Offline-Saved` time, because it was written on top of the words just saved. The page shows "Back online. 2 notes you wrote offline are saved." (frame `phone-offline-back.png`)
  - 409: a conflict (below); the save stays, `state: "conflict"`
  - 422: refused, as an online save would be (a blank title); the save stays, `state: "refused"`, and Settings → Offline shows it with "Open", which opens the form with what was written
  - 403 or 404 (the note was deleted, or the person left the household): the save stays, `state: "failed"`, with "Discard" in Settings → Offline
  - no `Aglowy-Offline-Saved` header (the sign-in page, say), or a network error: it goes back to `waiting` for the next try
- **A new Note offline** carries a `personal_note[offline_token]`, a UUID made on the device. `personal_notes.offline_token` (uuid, nullable, unique with `user_id`) means a save sent twice, because the first answer was lost, finds the first note instead of making a second. The note also keeps `personal_notes.offline_revision` (uuid, nullable): the `revision` that created it.
  - **A create with a token that already exists** writes nothing. If the stored `offline_revision` is the revision sent, the first send did save it: the answer is `200` with `Aglowy-Offline-Saved: <updated_at>` and `Location`, and the save is deleted as usual.
  - **If the revision differs,** the person wrote more on the phone after the first send. The answer is `200` with `Aglowy-Offline-Created: <the note's created_at>` and `Location`, and no `Aglowy-Offline-Saved`. The `offline` controller turns the waiting save into an update of that note (its URL, `PATCH`, `base` = that `created_at`) and sends it again at once. If nobody changed the note since it was created, its `updated_at` still equals `created_at` and the newer words save. If somebody did, it's a conflict like any other (Changed on another device).
  - Without the replay header, a create with an existing token redirects to the note.

### Changed on another device

Each of the three forms carries `offline_base`, a hidden field holding the record's `updated_at` (microseconds, ISO 8601) when the page was rendered. A new Note's is blank.

When a request has `Aglowy-Offline-Replay` and `offline_base` doesn't match the record's `updated_at`, the controller saves nothing and answers 409. `OfflineReplayable` does this in `update` in both controllers, under a row lock: `record.with_lock` is taken before `offline_base` is compared and held through the write, so a save from another device can't land between the check and the replay. Online saves, with no replay header, are unchanged.

Opening that note again, the `offline-form` controller finds the conflict for its URL and shows, under the form, "What you wrote offline · 10:41 AM" with the fields as text (escaped; rich text shown as plain paragraphs), "Copy" and "Discard what I wrote offline" (frame `phone-offline-conflict.png`). The page's banner says "This note changed on another device. It was saved there while you were offline, so what you wrote here wasn't saved over it. It's kept below." The server never sees the offline words unless the person pastes them in and saves.

## Signing out

The `offline` controller watches the sign-out forms (sidebar and header, `destroy_identity_session_path`).

- **Notes waiting:** online, it sends them first. Any still waiting (offline, refused, a conflict) are named in a Primer `Dialog`: "2 notes haven't saved yet. You wrote them offline, and they're only on this phone. Signing out removes them and everything else Aglowy kept here.", with "Stay signed in" and "Sign out and remove them" (frame `phone-offline-signout.png`).
- **Then it removes everything** (the `aglowy-pages-*` caches and the `aglowy-offline` database; assets can stay) and submits.
- **Signing out offline** can't reach the server, so it happens in two halves. The device half happens at once: everything is removed and the page shows "You're signed out on this phone. Aglowy finishes signing you out when you're back online." The server half waits: the controller keeps one record in a fresh `aglowy-offline` database, `{ pending_sign_out: <identity id> }`. The next page that loads online for that identity submits the sign-out straight away, before anything else, and shows the sign-in page. The worker serves nothing for that identity meanwhile. If the browser's storage is cleared, or the phone never comes back online, the session stays signed in on the server until it expires; nothing personal is left on the device either way.
- **A refresh that's still running** stops writing. Each removal increases a `generation` number stored with the settings. Every cache write and every removal holds the same Web Lock, `navigator.locks.request("aglowy-offline", ...)`, which pages and the worker share. A write takes the lock, checks that the identity and `generation` are still the ones the update started with, writes, and releases it. A removal takes the lock, increases `generation`, deletes the caches, and releases it. So a removal waits for a write already under way, and the next write sees the new `generation` and stops the update without writing. A removed cache can't be recreated.
- **A safety net:** on any page with no `aglowy-identity` meta (signed out) or a different identity, the controller removes the kept pages straight away. Waiting saves from a session that simply expired are kept for 14 days and sent only when the same identity signs in again. Another identity signing in removes them.

## Elsewhere

- `docs/design/notifications.md`: "It caches nothing. This isn't an offline app." becomes a pointer here.
- `docs/design/settings.md`: Offline joins the You group, for everyone.
- `CLAUDE.md` Stack: the service worker line names offline as well as push.

## Traps

1. **The server decides what's kept.** The worker stores a page only when the response says `Aglowy-Offline: keep`. A new page is kept only when its controller includes `OfflineKeepable`. Never add Settings, sign in, invitations, Madmin or AI pages.
2. **One person's copy, served only to them.** Caches are named by identity, the worker serves only the current identity's, and another identity, or none, removes them. Test two people signing in on one browser.
3. **A refresh is not a visit.** Check `Current.offline_refresh` anywhere a GET records something. The daily brief's pause rule depends on `seen_at` meaning the person looked.
4. **Redirects.** Keep a redirect as `Response.redirect`; a followed redirect can't answer a navigation and the page fails to load.
5. **No JSON API.** The kit is `text/plain`, a list of paths. Nothing else is added for the worker.
6. **The words stay on the device until they save.** No offline text goes to the server except as the normal form submission it would have been. The conflict panel is built on the device from IndexedDB.
7. **A save sent twice.** A new Note's `offline_token` stops a duplicate, and its `offline_revision` tells a repeat of the same save from newer words, which go on as an update. An edit sent twice after a lost answer comes back 409 the second time, and shows a conflict whose offline words are already in the note: harmless, and the person discards it.
8. **Escape everything shown from IndexedDB.** The conflict panel and Settings' list use `textContent`, never `innerHTML`.
9. **Saved means `Aglowy-Offline-Saved`.** Never treat a 2xx or a followed redirect as a save. Delete a waiting save only when it still holds the revision that was sent.
10. **Lock, then compare.** The `offline_base` check and the replay's write happen inside one `with_lock`.
11. **Turn off means gone.** "Turn off and remove" and sign out delete the caches and the database, and the worker stops answering `fetch` the moment `enabled` is false.
12. **Testing offline.** Chrome under Selenium can go offline with `page.driver.browser.network_conditions = { offline: true, latency: 0, throughput: 0 }`. Check in the first story that the service worker's own fetches are offline too, and say in its PR what was found.

## States each story checks

- Off; turning on; on and up to date; on and updating; turned off
- Online, offline, and back online
- A kept page, a page not kept, a kept page more than 14 days old, a redirect
- A note written offline: waiting, saved on return, refused, conflict, deleted meanwhile, sent twice
- A new Note offline, saved once
- Sign out with nothing waiting, with notes waiting online, and offline (the server half finished on return); a session that expired; another person signing in; a refresh running when the identity changes
- A save replayed while a newer one is written on the phone; a replay answered with the sign-in page
- A kit page never opened, then used offline with its assets; the same after a deploy
- A child turning it on for their own device
- A refresh of the daily brief page and Home, which records no visit
