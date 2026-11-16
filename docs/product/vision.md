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
| 7 | Notifications: in-app list and email | Design done |
| 8 | Production on AWS: EC2 + Docker Compose, SES, bounce handler | Stack decided |
| 9 | **KIDS-01** Today's meeting: meeting times, the right note for everyone, and the meeting helper for children (marks, drawing, sharing with the family) | Design done |
| 10 | **SCRIPT-01** Scripture links in notes: a book, chapter and verse picker, typed references linked on save, links to jw.org only | Design done |
| 11 | **AI-01** AI foundation and family study drafts: one job per feature, search limited to jw.org and wol.jw.org, links never copies, 10 drafts per household a day | Design done |
| 12 | **TAGS-01** Personal tags on meeting notes, personal goals and personal studies, with a page per tag | Design done |
| 13 | **PSTUDY-01** Personal study: topics with an AI conversation from jw.org and wol.jw.org, notes, collections; AI for children when a head allows it | Design done |
| 14 | **NOTES-01** Notes: a title and body with scripture links, JW Library-style colors, collections shared with Personal study, tags, pins, pinned notes on Home | Design done |
| 15 | **SETTINGS-01** One Settings page, a page per section: the person's own settings, tags and collections, then the household's | Design done |
| 16 | **BOOKMARKS-01** Bookmarks: save jw.org pages and scriptures from studies and notes, with comments, collections and tags, in a tab beside Notes | Design done |

Design docs live in `docs/design/`; briefs in `docs/briefs/`.

## Ideas parking lot

Not planned. Each needs a design pass and Casey's go-ahead before it becomes an epic.

- Audio versions of personal study, to listen to while exercising
- Age-appropriate versions of a family study for children
- Weekly planning drafted by a background job for parents to review
- A wider family-support area (fitness, meal planning)
