# USERS-01 — Households, people and login

**Goal.** A visitor signs up and becomes head of a new household, confirms their email, signs in and lands in their household. They can create another household, switch between households, see the members, and, as a head, add a member who has no login. Platform staff keep Madmin and impersonation. The suite passes with **100% line coverage, enforced**.

> **Delivered as stories.** Epic #12, stories #2–#11 on GitHub, one PR each. The stories split this brief's phases smaller and fix one gap: removing Devise from `User` (story #4) also renames `current_user` through the template, so the suite stays green after every story. **Where a story and this brief differ, the story wins.**

**Read first:** `CLAUDE.md`, then `docs/design/users.md` (Summary, Core models, Relationship rules, gotchas 1–6 and 10, Scenarios for USERS-01).

**Work in plan mode first.** Produce a plan that cites the design doc's sections, wait for Casey's approval, then build one phase at a time. Each phase ends green (`bin/rails test:all`), lint-clean (`bin/rubocop`), and is its own commit.

---

## Decisions already made (don't relitigate)

| Decision | Detail |
| --- | --- |
| User is the person | `users`: `name`, `time_zone`. No email, no role |
| Identity is the login | Devise moves from `User` to `Identity`. One per person, optional. `identities.user_id` not null, unique |
| Membership is the seat | `role` head/adult/child (string, check constraint), `active` boolean. One person, many households |
| Platform admin | `identities.staff` boolean replaces `users.role` admin/user. Madmin and impersonation check `staff?` |
| Replace the Devise migration | Delete `db/migrate/20260311033921_devise_create_users.rb`; nothing is deployed. New migrations create `households`, `users`, `identities`, `memberships` |
| `Membership.active` stays a boolean | Documented exception to CLAUDE.md's state-as-records rule |
| Sign-up | A `Signup` model in `app/models` (ActiveModel, not a service object) plus `SignupsController` (`resource :signup, only: %i[new create]`). Identity drops `:registerable` |
| Devise modules on Identity | `database_authenticatable, recoverable, rememberable, validatable, confirmable, lockable` |
| Household URLs | `scope "/:household_id"` with a UUID constraint, `as: :household` |
| Non-members | 404, never 403 (don't confirm the household exists) |
| Pundit | `pundit_user` returns `Current.membership` (nil outside household URLs) |

## Out of scope (do not build)

Invitations, guests, family studies, sessions, resources, goals, meeting notes, notifications, Action Text, Active Storage, giving a child a login, account settings (change email/password), household deletion, a UI for changing roles or leaving a household, billing, design-system work beyond using Primer components in the new pages. If something here seems necessary, stop and ask Casey.

---

## Phase 0a — Remove Ahoy analytics and Pay billing

**Before anything:** the working tree should hold only the handoff itself (`CLAUDE.md`, `docs/design/users.md`, this brief), committed by Casey as `Add users domain design and USERS-01 brief`. If anything else is uncommitted, stop and ask; never mix unrelated work into these commits.

Both came with the KinRails template and Aglowy uses neither. Aglowy keeps no tracking: Ahoy goes, along with MaxMind and Geocoder, which only Ahoy used. Billing isn't planned: Pay and Stripe go too. Pay was never installed (no migrations, initializer or models), so it's only the gems and leftover references.

1. Remove `ahoy_matey`, `maxminddb`, `geocoder`, `pay` and `stripe` (and the "Analytics" and "Billing" comment blocks) from the Gemfile; `bundle install`.
2. Delete `config/initializers/ahoy.rb`, `app/models/ahoy/` and `db/migrate/20260310133343_create_ahoy_visits_and_events.rb`. Nothing is deployed, so this follows the same approach as the Devise migration in Phase 1.
3. Remove the "Analytics (Ahoy + MaxMind)" block from `.env.development.example`, both "Billing (Pay + Stripe)" blocks from `.env.development.example` and `.env.test.example`, the `db/maxmind` entries in `.gitignore`, and the Ahoy and `pay:install` lines from `README.md` (keep the `ruby_llm:install` line). In `.env.development.example`, the comment "Used in mailers, Devise, and Pay." becomes "Used in mailers and Devise."
4. Rebuild the databases (`bin/rails db:drop db:create db:migrate`, then `bin/rails db:test:prepare`) so `db/schema.rb` loses the `ahoy_*` tables.
5. Check: searching `app`, `config`, `db`, `lib`, `test`, the Gemfile and the `.env` examples for `ahoy`, `maxmind`, `geocod`, `pay` (as a gem or `Pay::`) or `stripe` finds nothing, and the existing tests still pass.

**Commit:** `Remove Ahoy analytics and Pay billing from the template`

## Phase 0b — Coverage reporting

1. Add `gem "simplecov", require: false` to the `:test` group and `bundle install`.
2. Start SimpleCov at the very top of `test/test_helper.rb`, before Rails loads, with the `"rails"` profile, `enable_coverage :branch` (reported, not enforced), and parallel-worker support:

   ```ruby
   # in ActiveSupport::TestCase
   parallelize_setup    { |worker| SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" }
   parallelize_teardown { |_worker| SimpleCov.result }
   ```
3. Make sure every file under `app/` is loaded during coverage runs (`Rails.application.eager_load!` after the environment loads, or eager loading in test). Otherwise files no test touches are silently missing or show 0%, and local and CI numbers differ (`config.eager_load` is currently `ENV["CI"].present?`).
4. CI currently runs **only** `test:system` (`.github/workflows/ci.yml`). Change it to `bin/rails db:test:prepare test:all` so unit, integration and system tests run, and are counted, together.
5. No minimum yet. The template's existing code isn't covered; the gate turns on in Phase 4.

**Commit:** `Add SimpleCov coverage reporting and run the full suite in CI`

## Phase 1 — Schema and core models

1. Delete the Devise `users` migration. Generate migrations, all `id: :uuid`, references `type: :uuid`, real foreign keys:
   - `households`: `name` not null; `time_zone` not null default `"UTC"`.
   - `users`: `name` not null; `time_zone` nullable.
   - `identities`: every Devise column the template had (database_authenticatable, recoverable, rememberable, confirmable, lockable) plus `user_id` (not null, unique index, FK) and `staff` (boolean, not null, default false). Unique indexes on `email`, `reset_password_token`, `confirmation_token`, `unlock_token`.
   - `memberships`: `household_id`, `user_id` (not null, FKs); `role` string not null default `"adult"` with `check_constraint "role IN ('head', 'adult', 'child')"`; `active` boolean not null default true; unique index (`household_id`, `user_id`); index (`household_id`, `role`).
2. Rebuild the databases: `bin/rails db:drop db:create db:migrate` (regenerates `db/schema.rb`; `db:reset` would reload the old schema), then `bin/rails db:test:prepare`.
3. Models (see the design doc's Relationship rules):
   - `Household`: `has_many :memberships, dependent: :destroy`; `has_many :users, through: :memberships`; validates `name`; validates `time_zone` is an `ActiveSupport::TimeZone` name; `Household.create_with_head(household:, head:)` (one transaction); `#add_member(name:, role:)` creates a login-less User and its Membership (role `adult` or `child`).
   - `User`: `has_one :identity, dependent: :destroy`; `has_many :memberships, dependent: :destroy`; `has_many :households, through: :memberships`; `normalizes :name, with: -> { it.squish }`; validates `name`; `#active_households`.
   - `Identity`: the six Devise modules; `belongs_to :user`; `delegate :name, to: :user`.
   - `Membership`: `enum :role, %i[ head adult child ].index_by(&:itself), default: :adult, validate: true`; `scope :active`; `#sole_head?`; `#deactivate` and `#change_role(role)`, both refusing (return false with a base error) when they would leave the household with no active head, and both running `household.lock!` inside their transaction (gotcha 5).
   - Delete `test/models/user_test.rb`'s placeholder; replace `test/fixtures/users.yml`.
4. Fixtures, with generic names (no real family names):
   - `households`: `home`, `other`, `parents`.
   - `users`: `head`, `spouse`, `child` (no identity), `former` (inactive member), `outsider`, `grandparent`, `newcomer` (unconfirmed), `staff`.
   - `identities`: `head`, `spouse`, `former`, `outsider`, `grandparent`, `newcomer` (`confirmed_at: nil`), `staff` (`staff: true`). Passwords via `Devise::Encryptor.digest(Identity, "password123")`.
   - `memberships`: `head` head of `home` and adult in `parents` (two households); `spouse` adult in `home`; `child` child in `home`; `former` adult in `home`, `active: false`; `outsider` head of `other`; `grandparent` head of `parents`. `staff` and `newcomer` belong to no household.

**Commit:** `Split the Devise user into Identity and add households, people and memberships`

## Phase 2 — Sign-up and sign-in

1. Routes: `devise_for :identities, skip: :registrations`; `resource :signup, only: %i[new create]`.
2. `Signup` (`app/models/signup.rb`, `ActiveModel::Model` + `ActiveModel::Attributes`): `name`, `email`, `password`, `household_name`, `time_zone`. `#save` validates, then in one transaction creates the User, its Identity, and the Household via `create_with_head`. On `ActiveRecord::RecordInvalid` it copies the failing record's errors and returns false; nothing is left behind.
3. Devise sends the confirmation email in an `after_commit` on the identity. Inside `Signup`'s transaction it fires only if the whole sign-up commits. Keep it that way; don't send mail manually.
4. `SignupsController` (public): `new`, `create`. On success, redirect to the sign-in page with "Check your email to confirm your account." On failure, re-render with `status: :unprocessable_content`. Use Primer form components and pass `assert_accessible`.
5. `after_sign_in_path_for(identity)`, using **active** memberships only: none → `new_household_path`; one → that household's `household_root_path`; several → `households_path`.
6. Devise views: point the "Sign up" link at `new_signup_path` (the shared links partial hides its own link once `:registerable` is gone). Keep `config.responder.error_status` / `redirect_status` in `config/initializers/devise.rb`; Turbo needs them.
7. Optional: add `letter_opener` to the `:development` group (CLAUDE.md lists it, but the Gemfile doesn't) so confirmation emails can be clicked locally.

**Commit:** `Sign up creates a household with its head`

## Phase 3 — Household scope and authorization

1. `Current`: `attribute :identity, :user, :membership, :household`. Setting `identity` sets `user`; setting `membership` sets `household`.
2. `ApplicationController`: `before_action :authenticate_identity!, unless: :devise_controller?`; set `Current.identity = current_identity`; `pundit_user` → `Current.membership`; keep `after_action :verify_authorized` (Devise controllers and the public `HomeController`/`SignupsController` skip it, as CLAUDE.md shows); `rescue_from Pundit::NotAuthorizedError` → redirect back to the household page with an alert, `status: :see_other`.
3. `HouseholdScoped` concern (`app/controllers/concerns/household_scoped.rb`): `Current.membership = Current.user.memberships.active.find_by!(household_id: params[:household_id])`; `default_url_options` merges `household_id`. `find_by!` raises `RecordNotFound`, which is a 404 in every environment.
4. Routes:

   ```ruby
   resources :households, only: %i[ index new create ]

   scope "/:household_id", as: :household,
         constraints: { household_id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ } do
     get "/", to: "dashboards#show", as: :root
     resources :members, only: %i[ new create ]
   end
   ```
5. Controllers:
   - `HouseholdsController` (not scoped): `index` (chooser: the current user's active households), `new`, `create` (current user becomes head via `create_with_head`).
   - `DashboardsController` (scoped): `show` — household name and its active members with roles.
   - `MembersController` (scoped): `new`, `create` → `Current.household.add_member`. Heads only.
6. Policies: rewrite `ApplicationPolicy` around `membership` (`initialize(membership, record)`; helpers `member?`, `head?`; delete the template's `admin?`, `owner?` and user-based `Scope`). Add `HouseholdPolicy` (`index?`/`new?`/`create?` true for any signed-in person; `show?` requires an active membership) and `MembershipPolicy` (`create?` heads only).
7. Layout: a household switcher listing `Current.user.active_households` when signed in, plus sign out. Primer components; landmarks intact.

**Commit:** `Scope pages to the current household and authorize by membership`

## Phase 4 — Staff admin, cleanup and the 100% gate

1. `Madmin::ApplicationController`: `authenticate_identity!`, then refuse unless `current_identity.staff?`. Regenerate Madmin resources for `Identity`, `User`, `Household`, `Membership`; delete `UserResource`'s Devise columns; **never show `encrypted_password` or any token**. Update `config/routes/madmin.rb`.
2. `Admin::ImpersonationsController`: staff only; `params[:identity_id]`; `session[:staff_identity_id]`; `sign_in(:identity, ...)`. Start impersonation from the identity's Madmin page.
3. `home/index.html.erb`: remove the hard-coded "Impersonate test user" button and its fixed UUID. `shared/_impersonation_banner.html.erb`: `current_identity.email`, keyed on `session[:staff_identity_id]`.
4. `db/seeds.rb`: idempotent, development only — one staff identity and one demo household with a head, a spouse and a login-less child.
5. Turn the gate on: `minimum_coverage line: 100`. The only allowed filters are the `"rails"` profile defaults and `app/controllers/design_system_controller.rb` (its route exists only in development). No other filters and no `# :nocov:` without Casey's approval.
6. **Prove the gate bites:** delete one test, run `bin/rails test:all`, confirm it fails on coverage, restore the test. Report the result.
7. Update `CLAUDE.md` with any correction Casey made during this brief.

**Commit:** `Move platform admin to staff identities and enforce 100% coverage`

---

## Acceptance tests

Write each phase's tests **first**, show them to Casey, then make them pass. Test database constraints with `insert!` or `update_column` so they prove the database, not the model.

### Phase 1 — models (`test/models/`)

**`household_test.rb`**
- requires a name
- rejects a time zone that isn't an `ActiveSupport::TimeZone` name
- `create_with_head` creates the household and a head membership
- `create_with_head` creates nothing when the head membership is invalid
- `add_member` creates a user with no identity and a membership with the given role
- database: a household without a name raises `ActiveRecord::NotNullViolation`

**`user_test.rb`**
- squishes the name (`"  Mia   Rivera "` → `"Mia Rivera"`)
- requires a name
- `active_households` excludes households where the membership is inactive
- database: a user without a name raises `ActiveRecord::NotNullViolation`

**`identity_test.rb`**
- requires a user
- `staff` defaults to false
- an unconfirmed identity is not active for authentication
- database: a duplicate email raises `ActiveRecord::RecordNotUnique` (gotcha 3)
- database: a second identity for the same user raises `ActiveRecord::RecordNotUnique`

**`membership_test.rb`**
- role defaults to adult
- an unknown role is a validation error, not an `ArgumentError`
- database: role `"admin"` violates the check constraint (`ActiveRecord::CheckViolation`)
- database: the same person twice in one household raises `ActiveRecord::RecordNotUnique`
- database: a membership for a missing household raises `ActiveRecord::InvalidForeignKey`
- `sole_head?` is true for the only active head, false when another active head exists, false for adults
- an inactive head doesn't count as a head
- `deactivate` refuses the sole head and leaves it active
- `deactivate` works for an adult
- `change_role` refuses to demote the sole head
- `change_role` demotes a head when another active head exists
- `deactivate` and `change_role` lock the household row (`assert_queries_match(/FOR UPDATE/)`)

### Phase 2 — sign-up and sign-in

**`test/models/signup_test.rb`**
- a valid sign-up creates exactly one Identity, User, Household and head Membership (`assert_difference` on all four)
- a duplicate email creates none of the four and exposes the email error
- a missing household name is invalid and creates nothing
- a valid sign-up sends one confirmation email; an invalid one sends none

**`test/controllers/signups_controller_test.rb`**
- `GET /signup/new` renders for a visitor
- a valid `POST /signup` redirects to sign-in with the confirmation notice
- an invalid `POST /signup` responds 422 and creates nothing

**`test/controllers/sessions_test.rb`** (integration)
- an identity with one active household lands on that household's page
- an identity with several active households lands on the chooser
- an identity with no active household lands on new household
- an unconfirmed identity can't sign in
- an inactive membership doesn't count toward the landing page

### Phase 3 — scope and authorization

**`test/models/current_test.rb`**
- setting `identity` sets `user`; setting `membership` sets `household`

**`test/policies/household_policy_test.rb`, `membership_policy_test.rb`**
- `HouseholdPolicy#show?`: head, adult and child yes; nil membership no; inactive membership no
- `HouseholdPolicy#create?`/`index?`: yes with a nil membership
- `MembershipPolicy#create?`: head yes; adult, child and nil no

**`test/controllers/households_controller_test.rb`**
- a visitor is redirected to sign in
- `index` lists only the current user's active households
- `create` makes the current user head of the new household and redirects to it
- an invalid household re-renders with 422

**`test/controllers/dashboards_controller_test.rb`**
- a member sees the household name and its active members
- a non-member gets 404 (gotcha 6)
- a former (inactive) member gets 404
- a `household_id` that isn't a UUID gets 404

**`test/controllers/members_controller_test.rb`**
- a head adds a child: one new User, no Identity, one child Membership
- an adult is refused with an alert and nothing is created
- a blank name re-renders with 422

### Phase 4 — staff and system tests

**`test/controllers/admin/impersonations_controller_test.rb`**
- staff can start and stop impersonating an identity
- a non-staff identity is refused
- stopping without impersonating redirects home

**`test/controllers/madmin_access_test.rb`**
- staff get 200 on `/madmin`
- a non-staff identity is redirected with "Not authorized"
- a visitor is redirected to sign in

**System tests (`test/system/`), each page checked with `assert_accessible`**
- `sign_up_test.rb`: sign up → open the confirmation link from the delivered email → sign in → see the new household's page
- `household_switching_test.rb`: the two-household person lands on the chooser, opens one, switches to the other
- `add_member_test.rb`: a head adds a child and sees them in the member list
- the existing `smoke_test.rb` keeps passing

---

## Traps (from the current code)

1. **`current_user` is everywhere in the template.** `ApplicationController`, `Admin::ImpersonationsController`, `Madmin::ApplicationController`, `home/index.html.erb` and `shared/_impersonation_banner.html.erb` use `current_user`, `authenticate_user!` or `sign_in(:user, ...)`. All become `current_identity`, `authenticate_identity!`, `sign_in(:identity, ...)` (gotcha 2).
2. **`authenticate_identity!` in `ApplicationController` also runs on Devise's own controllers** and redirect-loops the sign-in page. Skip it with `unless: :devise_controller?`.
3. **`verify_authorized` runs after every action.** Each new controller authorizes, or (public pages only) skips it as CLAUDE.md shows.
4. **`pundit_user` is nil outside household URLs.** Policies for `households#index/new/create` must not call methods on it.
5. **404, not 403.** Use `find_by!` from `Current.user`, not `Household.find` plus a policy check (gotcha 6).
6. **One failing statement per test.** A constraint violation aborts the Postgres transaction the test runs in; any query after it in the same test fails. Make the violating `insert!` the last statement.
7. **`insert!` skips callbacks,** so `ApplicationRecord`'s UUIDv7 `before_create` doesn't run; the column's `gen_random_uuid()` default fills the id. Fine for constraint tests; don't assert v7 there.
8. **Fixture passwords** use `Devise::Encryptor.digest(Identity, ...)`, not `User`.
9. **Madmin's generator copies every column,** including `encrypted_password` and tokens. Remove them from the resources.
10. **SimpleCov with parallel tests** needs the `parallelize_setup`/`parallelize_teardown` hooks above, and the gate must be judged on a run of the whole suite (`test:all`). Running unit tests alone will fall below 100% because some lines are only reached by system tests.
11. **The home page has a hard-coded impersonation UUID.** Remove it (Phase 4).

## Definition of done

- [ ] `bin/rails test:all` passes locally and in CI
- [ ] SimpleCov reports 100% line coverage, the gate is on, and deleting a test was shown to fail it
- [ ] `bin/rubocop`, `bin/brakeman` and `bin/rails zeitwerk:check` are clean
- [ ] Every page in the flows passes `assert_accessible`
- [ ] Manual check in the browser: sign up, confirm, sign in, create a second household, switch, add a child, sign out
- [ ] Six commits, one per phase, with no unrelated changes mixed in
- [ ] `CLAUDE.md` updated with any correction made along the way

## Open problems (for Casey, not for the code)

1. **Account settings** (change email or password, close login) — next brief, along with giving a child a login.
2. **Devise `mailer_sender`** is still the placeholder; set it before SES goes live.

## Prompt for Claude Code

> Read `CLAUDE.md` and `docs/design/users.md`, then `docs/briefs/USERS-01-households-and-login.md`. Start in plan mode: give me a plan for Phases 0a, 0b and 1 that cites the design doc, and list the Phase 1 acceptance tests you'll write first. Don't write code until I approve. Build one phase at a time, run `bin/rails test:all` and `bin/rubocop` at the end of each, and stop for my review before committing.
