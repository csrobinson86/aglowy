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
- Content from outside approved sources: study material is quoted and linked from jw.org and wol.jw.org

## Roadmap

Each epic is broken into small stories (GitHub issues labelled `story`). Order can change; the vision above doesn't change without Casey.

| # | Epic | Status |
| --- | --- | --- |
| 1 | **USERS-01** Households, people and login | Stories filed |
| 2 | **UI-01** App shell: sidebar, navigation, page patterns | Stories filed |
| 3 | Invitations, child logins and account settings | Design done |
| 4 | Family studies: scheduling, sessions, resources, guests | Design done |
| 5 | Meeting notes (Action Text, Lexxy) | Design done |
| 6 | Goals: personal and family | Design done |
| 7 | Notifications: in-app list and email | Design done |
| 8 | Production on AWS: EC2 + Docker Compose, SES, bounce handler | Stack decided |

Design docs live in `docs/design/`; briefs in `docs/briefs/`.

## Ideas parking lot

Not planned. Each needs a design pass and Casey's go-ahead before it becomes an epic.

- Audio versions of personal study, to listen to while exercising
- AI-assisted study material (outlines, diagrams) drawn only from jw.org and wol.jw.org, quoted and linked, kept within the family
- Age-appropriate versions of a family study for children
- Weekly planning drafted by a background job for parents to review
- A wider family-support area (fitness, meal planning)
