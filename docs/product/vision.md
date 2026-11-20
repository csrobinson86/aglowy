# Aglowy — Vision

*"Aglow with the spirit."* (Romans 12:11)

Aglowy helps a family keep its spiritual routine together: schedule family studies, take notes at meetings, and set spiritual goals, individually and as a household. It's built first for Jehovah's Witness families and works for other faiths too.

This document is what the project manager checks every story against. If a story doesn't serve a goal below, or breaks a principle, it doesn't get built. Changing this file is Casey's call.

## Goals

1. **A family can run its study routine in Aglowy.** Schedule a family study once or on a repeating schedule, keep its topic, notes and resources, and invite a guest when it makes sense.
2. **Each person keeps their own spiritual record.** Meeting notes and personal goals belong to the person and go with them, even if they move to another household.
3. **Households work the way real families do.** Parents (heads) run the household, children are members without needing a login, and one person can belong to more than one household.
4. **It's calm and trustworthy.** Fast pages, clear wording, nothing that nags, and data that stays private to the family.

## Principles

| Principle | What it means in practice |
| --- | --- |
| Family first | The household is the unit; heads decide household-wide settings |
| Personal content follows the person | Notes and personal goals belong to `User`, never to a household seat |
| Private by default | No analytics or tracking. Personal text is encrypted. A household is invisible to non-members (404). Staff use Madmin, not household pages |
| Minimal data on children | A child needs a name and nothing else; no email or birthdate until a head gives them a login |
| Vanilla Rails | Rails' own tools first; a gem only when Rails has no answer; no service layer |
| Small, reviewed steps | Every change is a small story with named acceptance tests, reviewed before merge, at 100% test coverage |

## Non-goals (for now)

- Analytics, tracking or usage metrics of any kind
- Billing or paid plans
- Public profiles, social feeds or sharing outside a household (guests see only the sessions they're invited to)
- A public JSON API or a native mobile app
- Content from outside approved sources: study material is linked from jw.org and wol.jw.org, never copied into Aglowy (their terms of use; see `docs/design/ai.md`)

## Roadmap

Each epic is broken into small stories (GitHub issues labelled `story`). Order can change; the vision above doesn't change without Casey.

| # | Epic | Status |
| --- | --- | --- |
| 1 | **USERS-01** Households, people and login | Done |
| 2 | **UI-01** App shell: sidebar, navigation, page patterns | Done |
| 3 | **INVITES-01** Invitations, child logins (username sign-in), account and household settings | Stories filed |
| 4 | **STUDIES-01** Family studies: scheduling, sessions, notes, resources (guests, "all future" edits and the AI helper follow) | Stories filed |
| 5 | **NOTES-01** Meeting notes: Life and Ministry, weekend, spiritual gems, sharing with the household | Stories filed |
| 6 | **GOALS-01** Goals: family and personal milestone goals, steps, sharing (habit goals follow) | Stories filed |
| 7 | **NOTIFY-01** Notifications: an inbox for everyone, email and phone push for those who turn them on, quiet hours; the weekly preview, family study topic, shared with you and invitation alerts | Design done |
| 8 | Production on AWS: EC2 + Docker Compose, SES, bounce handler | Stack decided |
| 9 | **KIDS-01** Today's meeting: meeting times, the right note for everyone, and the meeting helper for children (marks, drawing, sharing with the family) | Design done |
| 10 | **SCRIPT-01** Scripture links in notes: a book, chapter and verse picker, typed references linked on save, links to jw.org only | Design done |
| 11 | **AI-01** AI foundation and family study drafts: one job per feature, search limited to jw.org and wol.jw.org, links never copies, 10 drafts per household a day | Design done |
| 12 | **TAGS-01** Personal tags on meeting notes, personal goals and personal studies, with a page per tag | Design done |
| 13 | **PSTUDY-01** Personal study: topics with an AI conversation from jw.org and wol.jw.org, notes, collections; AI for children when a head allows it | Design done |
| 14 | **NOTES-01** Notes: a title and body with scripture links, JW Library-style colors, collections shared with Personal study, tags, pins, pinned notes on Home | Design done |
| 15 | **SETTINGS-01** One Settings page, a page per section: the person's own settings, tags and collections, then the household's | Design done |
| 16 | **BOOKMARKS-01** Bookmarks: save jw.org pages and scriptures from studies and notes, with comments, collections and tags, in a tab beside Notes | Design done |
| 17 | **CAL-01** Calendar: the household's meetings, family studies and events for everyone; each person's own times, private unless shared; done marks, Today on Home and a private phone calendar link | Design done |
| 18 | **AVATAR-01** Avatars: a photo or your initial in a color you pick; heads and adults set children's; photos cropped and stripped of location on the server | Design done |
| 19 | **PARTS-01** Meeting parts: each person's student parts in Apply Yourself to the Field Ministry, with preparation, counsel and sharing; an AI outline, sample wording and changes for heads and adults, aimed at the part's time | Design done |
| 20 | **BRIEF-01** Daily brief: a brief ready each morning from the person's own plan of focus areas, with the day's text, a reading, a quality and a faith example tied by one thread; evening questions; written by AI for heads and adults, with a plan-only brief when there's no AI | Design done |
| 21 | **OFFLINE-01** Offline: turned on per device in Settings; the pages for the meeting, the ministry, the morning and family study kept on the device; meeting notes and Notes written offline and saved when back online, never over a newer version; everything removed on sign out | Design done |
| 22 | **GAME-01** Listening game: the meeting helper's Treasures, Spiritual Gems, Bible Reading and Congregation Bible Study steps as rounds of four cards found by a weekly AI research job, checked by a parent; a score for that meeting only; the child's own typed answer for the Bible Study | Design done |
| 23 | **STUDYNOTE-01** One note per study: "Save to note" adds each answer to the study's note in Notes, shown beside the conversation and edited in place; notes open read-only with Edit | Design done |
| 24 | **PREP-01** Get ready: a weekly AI job writes a few simple cards for each meeting for children using the meeting helper (what each part is about, a quality of Jehovah, one thing to do, the Bible reading as a story to draw), shown to her straight away and changeable by a parent; her own comment for the Watchtower Study and the Bible Study | Design done |

Design docs live in `docs/design/`; briefs in `docs/briefs/`.

## Ideas parking lot

Not planned. Each needs a design pass and Casey's go-ahead before it becomes an epic.

- Audio versions of personal study, to listen to while exercising
- Age-appropriate versions of a family study for children
- Weekly planning drafted by a background job for parents to review
- A wider family-support area (fitness, meal planning)
