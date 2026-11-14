# Users Domain Model

Repo copy of the design, 13 Nov 2026. The working version lives in the "Aglowy — Users Domain Model" doc (https://claude.ai/artifact/RrJPwrHKXMA5xzu6LhGVHx); when they disagree, ask Casey.

**Implementation status:** USERS-01 (`docs/briefs/USERS-01-households-and-login.md`) builds the four **core** models. Everything marked **planned** is design only. Do not build planned models until a brief asks for them.

## Summary

**User is the person, not a seat in a household.** Personal content (meeting notes, goals) belongs to the individual and follows them between households, so it hangs off a record that exists once per human.

- **User**: a person. Owns meeting notes and personal goals. Exists whether or not they ever log in.
- **Identity**: an optional login (Devise) attached to exactly one User. Platform staff are identities with `staff: true`.
- **Membership**: a User's seat in a Household, carrying the role (head, adult, child). One person, many households.
- **Household**: the family. Owns family studies and family goals.
- **FamilyStudy::Guest** (planned): a person invited to a session, or that session and all future ones. Sees only those sessions.

Basecamp's Fizzy is the reference codebase, but the names map differently: Fizzy's `Identity` is the person and its `User` is the per-account seat. Aglowy's `User` is the person and `Membership` is the seat, because Aglowy has data (notes, goals) that lives outside any one household.

## Core models (USERS-01)

All primary keys are UUIDv7 (set by `ApplicationRecord`), and every table has `created_at` / `updated_at`. Integrity rules live in the database (not null, unique, check, foreign key); model validations exist to give forms friendly errors.

### Household

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `name` | string | not null | "The Robinson Family" |
| `time_zone` | string | not null, default `UTC` | Family studies are scheduled and shown in it. Validate against `ActiveSupport::TimeZone` names |

### User

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `name` | string | not null | Display name; normalized with `squish` |
| `time_zone` | string | nullable | Personal reminders; a login-less child has none |

No email, birthdate or role here. Email belongs to the login, role belongs to the seat, and a birthdate is data on a minor the app doesn't need.

### Identity (Devise)

Replaces the template's Devise `users` table.

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `user_id` | uuid FK → users | not null, unique | Every login is exactly one person |
| `email` | string | not null, unique | Devise default column name |
| `encrypted_password` | string | not null, default `""` | Devise |
| `reset_password_token`, `reset_password_sent_at` | string, datetime | token unique | `:recoverable` |
| `remember_created_at` | datetime | | `:rememberable` |
| `confirmation_token`, `confirmed_at`, `confirmation_sent_at`, `unconfirmed_email` | string, datetimes, string | token unique | `:confirmable` |
| `failed_attempts`, `unlock_token`, `locked_at` | integer default 0, string, datetime | token unique | `:lockable` (kept from the template) |
| `staff` | boolean | not null, default false | Platform operators: Madmin and impersonation. Replaces the template's `users.role` admin/user |

Devise modules: `database_authenticatable, recoverable, rememberable, validatable, confirmable, lockable`. Not `registerable`: sign-up writes four rows, so it goes through `Signup` (gotcha 1).

### Membership

| Column | Type | Constraint | Why |
| --- | --- | --- | --- |
| `household_id` | uuid FK → households | not null | |
| `user_id` | uuid FK → users | not null | |
| `role` | string | not null, default `adult`, check in (`head`, `adult`, `child`) | Role is per household |
| `active` | boolean | not null, default true | Leaving keeps history; nothing is deleted. A deliberate exception to CLAUDE.md's state-as-records rule (decided 13 Nov 2026) |
| index | | unique (`household_id`, `user_id`) | A person sits once per household |
| index | | (`household_id`, `role`) | "Who are the heads here?" |

## Relationship rules

One test decides where anything new attaches: **who should see it?** Only the person → User. The family → Household.

```ruby
class Household < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
end

class User < ApplicationRecord
  has_one  :identity, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships
end

class Identity < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable,
         :validatable, :confirmable, :lockable
  belongs_to :user
end

class Membership < ApplicationRecord
  belongs_to :household
  belongs_to :user
  enum :role, %i[ head adult child ].index_by(&:itself), default: :adult, validate: true
end
```

- **The foreign key sits on `identities.user_id`.** Every login needs a person; not every person needs a login. A login-less User is a User with no Identity row.
- **Role lives on Membership.** The same person can be head of their own household and an adult child in their parents'.
- **Personal content never points at a Membership.** Leaving a household deactivates the seat and touches nothing the person owns.
- **Per request:** `current_identity` → `Current.user` → the active Membership for the `household_id` in the URL → `Current.household`. A person with no active Membership in that household gets a 404, not a 403, so the household's existence isn't confirmed.
- **Authorization:** Pundit's `pundit_user` is `Current.membership`. It is nil outside a household URL; policies for actions there must not read it.

## Planned models (not in USERS-01)

Kept here so USERS-01 doesn't paint them into a corner. Full column lists are in the working doc.

| Model | Owner | Purpose |
| --- | --- | --- |
| `MeetingNote` | User (`user_id`) | Notes from meetings, part by part on the meeting's outline; superseded by `docs/design/meeting-notes.md` |
| `Goal` | User **or** Household (two nullable FKs + `num_nonnulls(user_id, household_id) = 1`) | Personal or family goals; `set_by_id` records who wrote it |
| `FamilyStudy` | Household | The arrangement; one-off by default, can repeat daily/weekly/monthly |
| `FamilyStudy::Session` | FamilyStudy | One occurrence; `recurrence_at` (slot) vs `scheduled_at` (actual); Action Text notes |
| `FamilyStudy::Resource` | Session | Link or file (PDF/image), 25 MB max |
| `FamilyStudy::Guest` | FamilyStudy + User | Invited to one session or this-and-future; no household access |
| `Invitation` | Household **or** Session | Email invite; `generates_token_for :acceptance`; only the invited email can accept |
| `Notification`, `NotificationSetting` | User + Household | See the Notifications Design doc |

## Gotchas

Numbered so briefs can cite them. 1–6 and 10 apply to USERS-01.

1. **Sign-up writes four rows, and Devise only knows about one.** A new account is an Identity, a User, a Household and a head Membership in one transaction. Devise's registrations controller builds only the Identity, so sign-up goes through a `Signup` model in `app/models`.
2. **Devise on a model not named User.** `devise_for :identities` renames every helper: `current_identity`, `authenticate_identity!`, `identity_signed_in?`, `sign_in(:identity, ...)`. Anything from the template that says `current_user` breaks.
3. **Uniqueness needs the index, not just Devise.** `:validatable` checks email uniqueness in Ruby, which races. The unique index on `identities.email` is the real guarantee.
4. **Role is no longer on User.** "Is this person a head?" only has an answer inside a household. Policies receive the membership, not the user.
5. **The last head can vanish in a race.** A `sole_head?` check passes for two heads demoting each other at the same moment, leaving none. Lock the household row (`household.lock!`) inside the transaction that changes roles or deactivates a head.
6. **Cross-household leaks.** Every lookup starts from `Current`: `Current.household.memberships.find(id)`. A bare `Membership.find(params[:id])` lets anyone read any household's data by guessing an id.
7. **Encrypted text can't be searched in SQL.** Active Record Encryption is non-deterministic by default.
8. **One person, two clocks.** Studies render in the household's zone, personal reminders in the person's. Store UTC; pick the zone at render time.
9. **A polymorphic owner loses its foreign key.** Goal and Invitation use two nullable FKs plus a `num_nonnulls(...) = 1` check instead.
10. **Deleting a household must not delete a shared-custody child.** Never `has_many :users, dependent: :destroy` on Household. Destroy the memberships, then erase only children left with no Membership, in the same transaction.
11. **A child's goals are managed from more than one household.** Use `lock_version` on goal forms.
12. **Guests live outside the household URL scope.** One policy must decide both the member route and the guest route to a session.
13. **Signing up from an invite must not create a household.** Invite sign-up writes Identity + User only; `after_sign_in_path_for` sends someone with zero households but an active guestship to their session.
14. **Daylight saving time moves a naive schedule.** Compute each session from local `time_of_day` in the household zone (`ActiveSupport::TimeZone#local`), then store UTC.
15. **Sessions must exist as rows before they happen.** A recurring Solid Queue job keeps rows through the end of the service year (31 August), at least three months ahead, and is safe to run twice.
16. **"This session" versus "all future sessions."** Every date or time change asks which, like a calendar invite.
17. **Months without a fifth weekday follow iCalendar (RFC 5545):** skip them; offer "last Tuesday" (`week_of_month = -1`).
18. **The invited email must match, exactly.** Compare normalized emails at acceptance.
19. **Guest pages must allow fields, not hide them.** A separate guest view names exactly what it shows.
20. **Turbo Streams can leak what the page hides.** Separate streams for guests.
21. **A moved session must not come back.** Uniqueness is on `recurrence_at`, not `scheduled_at`.
22. **Active Storage links are signed, not authorized.** Serve files through a controller that runs the policy first.
23. **A link is user input.** Accept only `http` and `https`.
24. **A size limit must bite before the upload.** Check size when the direct-upload blob is created.

## Scenarios for USERS-01

| Scenario | What changes in the data | Guard |
| --- | --- | --- |
| First sign-up | Identity + User + Household + Membership (head), one transaction | Gotcha 1; all-or-nothing |
| Confirm email | `identities.confirmed_at` set | Devise `:confirmable`; can't sign in before |
| Sign in, one household | Lands on that household's page | `after_sign_in_path_for` |
| Sign in, several households | Lands on the household chooser | Only active memberships count |
| Sign in, no households | Lands on "create a household" | Possible after leaving every household |
| Create another household | Household + head Membership for the current user | Any signed-in person |
| Add a young child | User + Membership (child); no Identity | Heads only |
| Add a login-less adult | User + Membership (adult); no Identity | Heads only |
| Visit another family's household URL | Nothing | 404 (gotcha 6) |
| Last head demoted or deactivated | Nothing; refused | `sole_head?` under `household.lock!` (gotcha 5) |
| Staff opens Madmin / impersonates | Session switches to the target identity | `identities.staff`; other identities are refused |

Planned scenarios (invites, guests, child logins, shared custody, erasure, family studies) are in the working doc.

## Decisions

| Question | Decision |
| --- | --- |
| Can a person belong to more than one household? | Yes |
| Who owns personal content? | The individual (User); it follows them between households |
| Household roles | head, adult, child, on Membership |
| Who changes household-wide settings | Heads |
| Platform admin | `identities.staff`, replacing the template's `users.role` |
| Leaving a household | `memberships.active = false` (boolean kept; exception to state-as-records) |
| Schema change from the template | Replace the Devise `users` migration (nothing deployed) |
| Sign-up | `Signup` model + `SignupsController`; Identity drops `:registerable` |
| Household URLs | `scope "/:household_id"` with a UUID constraint |
| A non-member visits a household URL | 404 |
