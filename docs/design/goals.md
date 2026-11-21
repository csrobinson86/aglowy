# Goals

How a household sets family goals, breaks them into steps and ticks them off, and how a person keeps personal goals. Read this before touching `Goal`, its steps, completions, archivals or sharing. Stories for the first build live under the **GOALS-01** epic. Mockup frames are in `docs/design/goals/`.

This expands the `Goal` row sketched in `docs/design/users.md` (planned models, gotchas 9 and 11).

## Principles

- **Two owners, one model.** A family goal belongs to a `Household`; a personal goal belongs to a `User` and follows them between households (vision, principles). Exactly one of the two is set.
- **Adults run family goals, everyone can see them.** Heads and adults create, edit and finish family goals. Children see them and tick their own steps.
- **Personal goals are private by default.** Only the owner sees one until they share it with a household, read-only, like meeting notes.
- **Progress, not pressure.** Progress bars and counts show what's done and what's left. No streaks, no nagging, no reminders in GOALS-01 (vision goal 4).
- **Finished goals are kept.** Completing or archiving a goal never deletes it; the family can look back. Delete is a separate, deliberate action.

## Kinds of goal

| Kind | What it is | Built |
| --- | --- | --- |
| **Milestone** | Reach something by a target date, step by step ("Read the four Gospels together by March 31") | GOALS-01 |
| **Habit** | Something we keep doing ("Read the Bible together every evening"): a week of day check-ins and earlier weeks, no streaks | Later epic (frames `habit-goal-later.png`, `new-goal-habit-later.png`) |

GOALS-01 adds a `kind` column that only allows `milestone`, so the habit epic widens one check constraint rather than adding a column. The kind picker on the New goal form (frame `new-goal.png`) arrives with habits; GOALS-01's form has Title, Why and Target date only.

## What GOALS-01 builds, and what comes later

| In GOALS-01 | Later |
| --- | --- |
| Family milestone goals: list with Active, Completed and Archived tabs | Habit goals |
| A goal's page: why, progress bar, each person's count, steps | Goals on the household home |
| Steps for everyone or for named people, with an optional due date | Reordering steps by drag and drop |
| Ticking steps: done together, or each named person ticks their own | Reminders and notifications for due steps |
| Mark complete, reopen, archive, restore, delete | Personal goals for children without a login (gotcha 11) |
| Schedule a step as a family study | |
| My goals: personal milestone goals | |
| Share a personal goal with a household (one share per household, like meeting notes) | |

## Who can do what

**Family goals** (reached through `Current.household`):

| Action | Head | Adult | Child |
| --- | --- | --- | --- |
| See goals, steps and progress | yes | yes | yes |
| Create, edit, delete a goal; complete, reopen, archive, restore | yes | yes | no |
| Add, edit, remove steps | yes | yes | no |
| Tick an "Everyone" step (done together) | yes | yes | no |
| Tick a named person's part of a step | yes, for anyone named | yes, for anyone named | only their own |
| Schedule a step as a family study | yes | yes | no |

Adults tick for anyone because children don't need a login (vision goal 3).

**Personal goals** (reached through `Current.user`):

| Action | Owner | Member of a household it's shared with | Anyone else |
| --- | --- | --- | --- |
| See, edit, delete, add and tick steps, complete, archive | yes | no | no (404) |
| Read | yes | yes, read-only | no (404) |
| Share with / stop sharing in the current household | yes, if an active member there | no | no |

A goal that isn't visible is a 404, never a 403 (CLAUDE.md, Scoping). Children with a login keep personal goals like anyone else. Personal goal steps have no assignments and can't become family studies.

## Models

### `Goal`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid | FK → households, nullable, cascade | Family goal |
| `user_id` | uuid | FK → users, nullable, cascade | Personal goal |
| check | | `num_nonnulls(household_id, user_id) = 1` | One owner, keeping both foreign keys (gotcha 9) |
| `set_by_id` | uuid | FK → users, not null | "Set by Maria" |
| `kind` | string | not null, default `milestone`, check in (`milestone`) | Habit widens this later |
| `title` | string | not null, `encrypts :title` | Personal text is encrypted |
| `body` | text | nullable, `encrypts :body` | The "Why this goal?" text; plain text, no rich text |
| `target_on` | date | not null | Milestone target date |
| `lock_version` | integer | not null, default 0 | Two adults, or two households, editing at once (gotcha 11) |

Status comes from records, not a column (CLAUDE.md, State as Records):

- `Goal::Completion`: `goal_id` (unique, cascade), `completed_by_id` (FK → users, not null), `created_at`.
- `Goal::Archival`: `goal_id` (unique, cascade), `archived_by_id` (FK → users, not null), `created_at`.

Scopes: `active` (no completion, no archival), `completed` (a completion, no archival), `archived` (an archival). Active goals sort by `target_on`; completed by completion date, newest first; archived by archival date, newest first. A goal is **open** when it's neither completed nor archived; only open goals take new steps or ticks.

Methods: `goal.complete(by:)`, `goal.reopen`, `goal.archive(by:)`, `goal.restore`. Reopening deletes the completion; restoring deletes the archival (a completed goal that's restored goes back to Completed).

### `Goal::Step`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `goal_id` | uuid | FK → goals, not null, cascade | |
| `title` | string | not null, `encrypts :title` | |
| `due_on` | date | nullable | "Due Feb 15" |
| `position` | integer | not null | New steps go last; listed by position |
| `family_study_id` | uuid | FK → family_studies, nullable, `on_delete: :nullify` | Set when the step is scheduled as a study; validated to be in the goal's household, and only on family goals |

### `Goal::Step::Assignment`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `step_id` | uuid | FK → goal_steps, not null, cascade | |
| `user_id` | uuid | FK → users, not null, cascade | Must be an active member of the goal's household (validated) |
| unique index | | (`step_id`, `user_id`) | |

**No assignments means "Everyone".** Personal goal steps never have assignments.

### `Goal::Step::Completion`

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `step_id` | uuid | FK → goal_steps, not null, cascade | |
| `user_id` | uuid | FK → users, nullable, cascade | The person whose part this is; null for an "Everyone" step done together, and for personal goal steps |
| `completed_by_id` | uuid | FK → users, not null | Who ticked it ("Done by Eli", or an adult ticking for a child) |
| `created_at` | datetime | | "Jan 18" |
| unique index | | (`step_id`, `user_id`) `NULLS NOT DISTINCT` | One tick per person per step, and one "done together" tick. Needs PostgreSQL 15 or later |

**When a step is done** (decided 14 Nov):

- An "Everyone" step, or a personal goal step: when it has a completion with no `user_id`.
- A step for named people: when **every** assignee has their own completion. Until then it shows as partly done ("Eli done · waiting on Sofia") with a mixed checkbox, and each person has their own tick (frame `milestone-goal.png`, the parables step).

A completion's `user_id` must be null on an "Everyone" step and must be an assignee on a named step (validated). The rules below keep that true for every stored completion, not just new ones.

**Changing who a step is for** (`step.reassign(to:)`, one transaction, holding `household.lock!`): ticks that still fit stay, and ticks that no longer fit are deleted.

- Everyone → named people: the "done together" tick is deleted; each named person starts unticked.
- Named people → Everyone: the per-person ticks are deleted; the step starts unticked.
- Removing someone from a named step deletes their tick; adding someone leaves the others' ticks alone.

The edit form warns when ticks will be lost: "Changing who this is for clears 1 tick."

### Progress

`Goal::Progress` (a PORO in `app/models/goal/progress.rb`) answers, from preloaded steps, assignments and completions, without a query per step:

- `done_count` and `steps_count` ("3 of 7 steps done"), and the next undone step with a due date ("next due Feb 15").
- Per person, for each active member: steps that are theirs (every "Everyone" step plus steps naming them) and how many are done for them (an "Everyone" step done together, or their own tick). "Eli · 4 of 6".

When every step is done on an open goal, heads and adults see a Banner: "Every step is done. Mark the goal complete?" with the button. Nothing completes on its own.

### `Goal::Sharing` (personal goals only)

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `goal_id` | uuid | FK → goals, not null, cascade | Validated to be a personal goal |
| `household_id` | uuid | FK → households, not null, cascade | |
| unique index | | (`goal_id`, `household_id`) | |

The same rules as meeting notes (`docs/design/meeting-notes.md`, "Leaving ends a share for good"): `Membership#deactivate` deletes the person's goal sharings into that household in the same transaction; `Goal.shared_with(household)` joins the owner's active membership there; `goal.share_with(household)` takes `household.lock!` and rechecks the owner's membership before inserting.

### Leaving a household

`Membership#deactivate` also deletes the person's step assignments **and their ticks** on **steps not yet done** in that household's goals, in the same transaction and under the `household.lock!` it already takes (an explicit step in the method, not a callback). Otherwise a step naming only someone who left could never be finished. Assignments and ticks on done steps stay as history, so a stored tick always belongs to an assignee.

**One lock for every write.** Adding, editing and removing steps, creating or changing assignments (`reassign`), ticking and unticking (`tick`, `untick`), completing, reopening, archiving and restoring the goal, and the deactivation cleanup all take the same `household.lock!` first, then recheck under it before writing:

- Adding, editing or removing a step: the goal is still open.
- `reassign`: each new assignee is an active member.
- `tick`: the goal is still open. On a named step, the person whose part it is is still named and still an active member. An "Everyone" step needs no person check, and personal goal steps have no household, so no membership check applies to them.
- `untick`: the goal is still open. Nothing is checked about the person whose tick is removed, so an adult can always remove a departed member's tick.
- Lifecycle writes: the goal's current state (completing an already completed goal stays a no-op).

The acting person's own permission is the policy's job, before any of this. So an assignment can't slip in just after a deactivation, a tick can't land on a goal that was just archived, and a tick can't land for someone a reassignment has just removed. Personal goals have no household, so all their writes, lifecycle ones included, lock the goal row instead (`goal.lock!`).

**Unticking a step someone has left.** A done step can keep a departed member's assignment and tick as history. If it's later unticked on an open goal, `untick` also deletes the assignments and ticks of anyone no longer an active member, in the same locked transaction, so the step goes back to depending only on people who are still there.

In both cases, a step left with nobody named becomes an "Everyone" step (no assignments means everyone), so an adult can finish it or give it to someone else. That's intended, not a gap.

## Pages

All under `/:household_id` in the app shell (`docs/design/app-shell.md`). Primer components first; forms are Primer form classes. Sidebar: "Family goals" (`goal` octicon) in the **Household** group, "My goals" (`flag`) in **Mine**, each added in the story that builds its page.

| Page | Route | What's on it |
| --- | --- | --- |
| Family goals | `GET /:household_id/goals` (`?status=completed` or `archived`) | Frames `goals-list.png`, `goals-list-archived.png`. Subhead "Family goals" with "New goal" (heads, adults). UnderlineNav tabs Active, Completed, Archived with counts, and a line under them saying what the tab holds. A BorderBox row per goal: title link, a "Milestone" Label, target or completion/archival date, a ProgressBar with "3 of 7 steps", the next step or who completed/archived it, and avatars of the people involved. A Blankslate per empty tab |
| New goal | `GET /:household_id/goals/new` | Frame `new-goal.png` without the kind picker: Title, Why this goal? (optional, with the caption "Shown at the top of the goal so everyone remembers the reason."), Target date (`type: :date`), and the note "You'll add the steps next…". "Create goal" redirects to the goal's page |
| A goal | `GET /:household_id/goals/:id` | Frames `milestone-goal.png`, `milestone-goal-child.png`, `milestone-goal-dark.png`; on a phone, `docs/design/phone.md` (A goal) and its frames, which replace `phone-goal.png`. Breadcrumbs (Family goals or My goals / title), `h1` title, "Milestone" Label, "Target March 31, 2027 · Set by Maria", the why. Edit and a "…" ActionMenu (frame `milestone-goal-menu.png`): Mark goal complete, Archive, Delete goal… Progress box. Steps BorderBox; an add-step row at the bottom (New step, For, Due) for those who can edit. Completed and archived goals show a Banner saying so, with Reopen or Restore, and no tick boxes or add-step row |
| Edit a goal | `GET …/goals/:id/edit` | Title, Why, Target date. A stale form shows "Someone else changed this goal. Here's the latest." and the fresh values (`ActiveRecord::StaleObjectError`) |
| Delete a goal | `DELETE …/goals/:id` | A Primer Dialog: "Delete this goal? Its steps and progress are deleted too. Archive it instead to keep it for looking back." |
| Complete / reopen | `POST` / `DELETE …/goals/:goal_id/completion` (`Goals::CompletionsController`) | |
| Archive / restore | `POST` / `DELETE …/goals/:goal_id/archival` (`Goals::ArchivalsController`) | |
| Steps | `POST`, `PATCH`, `DELETE …/goals/:goal_id/steps(/:id)` (`Goals::StepsController`) | Edit a step in place in a Turbo Frame: title, For (Everyone or one or more members, a Primer multi-select), Due |
| Tick / untick | `POST` / `DELETE …/goals/:goal_id/steps/:step_id/completions(/:id)` (`Goals::Steps::CompletionsController`) | `user_id` param names whose part; blank for done together. Turbo Stream replaces the step row and the progress box |
| Schedule a step as a study | `GET /:household_id/family_studies/new?goal_step_id=…` | The existing form, topic prefilled with the step's title and date with its due date. Creating the study links the step in the same transaction. The step then shows "Family study · Tue, Feb 3" (the study's first session) linking to that session |
| My goals | `GET /:household_id/my_goals` (`PersonalGoalsController`, `index`/`new`/`create`) | Same list and tabs for the signed-in person's goals, plus a "Shared in this household" tab (`?status=shared`) listing personal goals others shared here, with the owner's name. Each personal goal opens at `/goals/:id` |
| Share / stop sharing | `POST` / `DELETE …/goals/:goal_id/sharing` (`Goals::SharingsController`) | Personal goals only. A Dialog like the meeting-notes one; a "Private" or "Shared with <household>" Label in the goal's header |

**Loading a goal:** `GoalsController` and the nested controllers find the goal in `Current.household.goals`, `Current.user.goals`, or `Goal.shared_with(Current.household)`, in one scope (`Goal.reachable_from(Current.membership)`); anything else is a 404. The policy then decides what the person may do with it.

**Policies** receive the membership: `GoalPolicy` (`show?`, `update?`, `destroy?`, and `complete?`/`archive?` through `update?`), `Goal::StepPolicy`, `Goal::Step::CompletionPolicy` (the child rule lives here: a child may create or destroy only a completion whose `user_id` is their own user, on a step naming them), `Goal::SharingPolicy`.

## Traps

- Everything typed is encrypted: goal title, body, step titles. Sort by dates, never by title, in SQL.
- The household in the URL isn't a personal goal's owner. Load personal goals through `Current.user.goals` or `Goal.shared_with(Current.household)`, never by id alone.
- A child must never tick an "Everyone" step or someone else's part, even by posting a crafted `user_id`. The policy checks it; the request test proves it.
- Assignees must be active members of the goal's household, checked on save, and their open assignments go when they leave.
- Progress counts come from preloaded records (`Goal.preloaded` includes steps, assignments and completions). A goal page or list with seven goals must not run a query per step.
- A family study linked from a step lives in the same household; a crafted `goal_step_id` from another household is a 404.

## States each story checks

- Viewer: head, adult, child (their own step, someone else's, an "Everyone" step), non-member (404); for personal goals: owner, a member it's shared with, anyone else
- Goal: no steps, some done, all done (the Banner), completed, archived, completed then archived, restored
- Steps: Everyone, one person, two people with one ticked, no due date, a long title, linked to a study
- Tabs: each empty and full
- A person who left the household while named on an open step
- Desktop and phone; light and dark

## Tags

The owner can tag a personal goal (never a family goal) with their own private tags (TAGS-01, `docs/design/tags.md`). Tags never show on shared views.
