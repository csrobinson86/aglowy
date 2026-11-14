# Aglowy — Claude Code Guide

This document defines the architecture, patterns, and conventions for Aglowy.
Read this before writing any code. Follow these patterns consistently.

---

## Philosophy

**Vanilla Rails is plenty.** Maximize what Rails provides out of the box.
Resist abstractions until you feel the pain. The best code is the code you don't write.

We follow the 37signals/DHH approach to Rails development, as practiced in
Basecamp and documented in the Fizzy open source project. Rich domain models,
thin controllers, concerns for shared behavior, and CRUD as the universal
interface for everything.

---

## Domain: People, Logins and Households

Read `docs/design/users.md` before touching anything about users, logins,
households or roles. The non-negotiables:

- **`User` is the person**, whether or not they ever log in. Personal content
  (meeting notes, goals) belongs to `User` and follows them between households.
- **`Identity` is the optional login.** Devise lives on `Identity`, one per
  person (`identities.user_id` is unique). Helpers are `current_identity`,
  `authenticate_identity!`, `identity_signed_in?`. There is no `current_user`.
- **`Membership` is a person's seat in a `Household`** and carries the role:
  `head`, `adult` or `child`. One person can sit in several households.
- **Platform staff** are identities with `staff: true` (Madmin, impersonation).
  Never put a role column on `User`.
- **Every household page lives under `/:household_id`.** Look the household up
  through the signed-in person (`Current.user.memberships.active.find_by!`), so
  a non-member gets a 404. Never `Household.find(params[:household_id])`.
- **`Current`** holds `identity`, `user`, `membership` and `household`.
- Design docs live in `docs/design/`; implementation briefs in `docs/briefs/`.

---

## Workflow: Stories, Builds and Reviews

- **Goals first.** `docs/product/vision.md` holds the goals, principles and
  non-goals. Don't build anything that contradicts it.
- **Work comes as stories**: GitHub issues labelled `story`, grouped under an
  `epic` issue. One story is one branch and one pull request. Don't widen a
  story's scope; if something outside it seems necessary, stop and ask Casey.
- **For each story:** plan mode first (cite the design doc) → write the
  story's named acceptance tests first and show them → implement until
  `bin/rails test:all`, `bin/rubocop` and `bin/brakeman` are clean → run the
  `code-reviewer` subagent and fix its Blockers and Majors → open the PR with
  `Closes #N`.
- **Reviews follow `REVIEW.md`.** Reviews advise; Casey merges. No agent
  approves or merges its own work.

---

## Stack

- Ruby 4.0.x / Rails 8.1
- PostgreSQL with UUIDv7 primary keys
- Devise for authentication
- Pundit for authorization (household roles on `Membership`; platform staff via `identities.staff`)
- Hotwire (Turbo + Stimulus) for frontend — no React, no HTMX, no GraphQL
- Sass via `dartsass-rails` (standalone binary; reads Primer CSS from `node_modules`)
- ViewComponent for reusable UI components
- Primer ViewComponents (`primer_view_components`) as the design system
- esbuild for JavaScript bundling (Yarn for package management)
- RubyLLM for AI (OpenAI + Anthropic, streaming)
- Solid Queue / Cache / Cable for background jobs, caching, Action Cable (DB-backed, no Redis)
- Madmin for admin (locked to staff identities)
- Minitest + Fixtures for testing
- Capybara + Selenium for system tests
- axe-core for automated accessibility testing
- dotenv-rails for environment variables (development/test only)
- letter_opener for email previews in development
- AWS EC2 + Docker Compose for deployment (no Kamal); Amazon SES for email; Cloudflare R2 for files

---

## Architecture Rules

### Business Logic

- Business logic lives in **models and concerns**. Never in service objects.
- There is no `app/services/` directory. Do not create one.
- POROs live in `app/models/` namespaced under their parent when appropriate
  (e.g., `Card::EventableDescription`, not a separate services layer).
- If logic doesn't map to a database-backed model, create a PORO in `app/models/`.

### Models

- Models are rich with behavior — methods, scopes, validations, callbacks.
- Use **concerns as adjectives**: `Closeable`, `Watchable`, `Assignable`, `Billable`.
  Each concern is self-contained with its own associations, scopes, and methods.
- Prefer **instance methods** over class methods. Class methods close doors on
  encapsulating state later.
- Never create "service objects" with a single `call` method. Name methods for
  what they do: `order.fulfill`, `membership.deactivate`.
- Use the `preloaded` scope convention for eager loading:
  ```ruby
  scope :preloaded, -> { includes(:user) }
  ```

### Controllers

- Controllers are **thin**. They orchestrate — they don't implement.
- The controller calls `@card.close`, the model handles the transaction,
  events, and side effects.
- Use concerns for shared controller behavior: `Authenticated`, `AdminOnly`.
- Use `before_action` in concerns for resource loading.
- **Public controllers** (home, marketing, design system) must skip Pundit:
  ```ruby
  class HomeController < ApplicationController
    skip_after_action :verify_authorized
  end
  ```
- **Madmin** is locked to staff identities via `authenticate_admin_user` in
  `Madmin::ApplicationController`. Uses `main_app.root_path` for redirects
  (Madmin is a Rails engine with its own routing scope).

### Routing

- **Everything is CRUD.** When an action doesn't fit a standard resource,
  create a new resource — don't add custom actions.
- `Cards::ClosuresController` with `create`/`destroy` instead of
  `cards#close` and `cards#reopen`.
- Prefer `resources :closures, only: [:create, :destroy]` nested under the
  parent resource.

### State as Records

- Instead of boolean columns (`closed: boolean`), **create a separate record**
  (`Closure`). This gives you timestamps, who did it, and clean scoping
  via `joins` and `where.missing`.
- This pattern applies to any state that matters: approvals, cancellations,
  completions, publications.

### Views

- Server-rendered ERB. Turbo Frames and Turbo Streams for dynamic updates.
- Stimulus controllers for JavaScript behavior.
- No client-side routing, no client-side state management.
- **Simple reuse** → partials with strict locals.
- **Complex UI logic, multiple states, or cross-page reuse** → ViewComponent.
- Converting a partial to a ViewComponent is straightforward — do it when
  logic grows or you need isolated tests.

### ViewComponent Conventions

- Components live in `app/components/` with sidecar ERB templates.
- All components inherit from `ApplicationComponent`:
  ```ruby
  # app/components/application_component.rb
  class ApplicationComponent < ViewComponent::Base
  end
  ```
- Expose data via `attr_reader`, not instance variables in ERB.
- Use `renders_one` / `renders_many` for named slots (content projection).
- Co-locate Stimulus controllers as sidecar files when component-specific.
- Component tests live in `test/components/` using `ViewComponent::TestCase`.
- Name components for what they render: `PlanCardComponent`, `BadgeComponent`,
  `NavigationComponent` — not `PlanCardHelper` or `PlanCardPartial`.

### CSS & Design System (Primer)

- We use GitHub's **Primer** design system via
  [Primer ViewComponents](https://primer.style/product/getting-started/rails/).
  Do not hand-build buttons, labels, banners, form fields, etc. — reach for
  the Primer component first (`Primer::Beta::Button`, `Primer::Alpha::TextField`,
  `Primer::Alpha::Banner`, ...). Reference: https://primer.style/product/components/
- `primer_view_components` (gem) and `@primer/view-components` (npm) are
  **pinned to the same exact version**. Upgrade them together. Pre-1.0:
  breaking changes land in patch releases. The library is in maintenance
  mode (security/P0 fixes only) as of Feb 2026.
- CSS comes from `@primer/css`, `@primer/view-components`, and
  `@primer/primitives`, `@use`d from `node_modules` in `application.scss`
  (load path set in `config/initializers/dartsass.rb`). JS is
  `import "@primer/view-components"` in `app/javascript/application.js`.
- Theming via `data-color-mode="auto" data-light-theme="light"
  data-dark-theme="dark"` on `<body>`. Any new layout must include these.
- **Design tokens are Primer primitives** (CSS custom properties like
  `var(--bgColor-default)`, `var(--base-size-16)`, `var(--fgColor-muted)`).
  Never use magic numbers — reference a primitive.
- Prefer Primer **utility classes** (`d-flex`, `gap-2`, `mb-4`, `color-fg-muted`)
  and component system arguments (`mb: 4`, `color: :muted`) for layout and
  spacing before writing custom Sass.
- Custom Sass is for app-specific components Primer doesn't cover. Those use
  **BEM naming** (`.plan-card`, `.plan-card__header`), one file per component
  in `app/assets/stylesheets/components/`, built from Primer primitives.
- `application.scss` is `@use` imports only — no loose styles.
- Never use inline styles.
- The **living style guide** (`/design-system` route in development)
  showcases Primer components as used in this app.

### App Shell and Page Patterns

- Read `docs/design/app-shell.md` before touching a layout, the sidebar,
  navigation, a page header or an empty state.
- Household pages use the `household` layout (sidebar + main, via
  `AppShellComponent`); pages outside a household use the `focused` layout.
- A navigation item appears only once its page exists.
- Look at your work: save desktop and phone screenshots from the system test
  and compare them with the mockup frames in `docs/design/app-shell/` before
  opening the PR.

### Forms (Primer Forms framework)

- Every form is a **Primer form class**, never hand-written form markup.
  Reference: https://primer-lookbook.github.com/view-components/lookbook/pages/forms/introduction
- Form classes live in `app/forms/`, mirroring `app/controllers/`, and inherit
  from `ApplicationForm` (`class ApplicationForm < Primer::Forms::Base; end`).
  Inputs and the submit button are declared in the `form do |f| ... end` DSL.
- Render inside `primer_form_with`, Primer's `form_with`:
  ```erb
  <%= primer_form_with(model: @signup, url: signup_path) do |f| %>
    <%= render SignupForm.new(f) %>
  <% end %>
  ```
  It turns off Rails' default error markup; Primer shows each validation
  message with its input, labels every field, and focuses the first invalid one.
- Active Model objects (like `Signup`) work the same as Active Record models.
- No custom Sass or layout work for forms. If Primer can't express something,
  ask Casey before building it by hand.
- Devise's generated views still use plain `form_for`. Convert them only in a
  story that asks for it.

---

## Authentication (Devise)

- **Devise** handles all authentication. Do not roll custom auth.
- Devise is on **`Identity`**, not `User` (see Domain above).
- Modules enabled: `database_authenticatable`, `recoverable`, `rememberable`,
  `validatable`, `confirmable`, `lockable`. **Not `registerable`**: sign-up
  creates an Identity, a User, a Household and a head Membership together, so
  it goes through the `Signup` model and `SignupsController`.
- Devise views are generated into the app for customization:
  ```bash
  bin/rails generate devise:views
  ```
- Identity model:
  ```ruby
  class Identity < ApplicationRecord
    devise :database_authenticatable, :recoverable, :rememberable,
           :validatable, :confirmable, :lockable

    belongs_to :user
  end
  ```
- `Current.identity` (and from it `Current.user`) is set in
  `ApplicationController`; `Current.membership` and `Current.household` are set
  by the `HouseholdScoped` concern.

---

## Authorization (Pundit)

- **Pundit** handles all authorization via policy objects in `app/policies/`.
- Every controller that accesses resources must call `authorize @record`.
- Use `after_action :verify_authorized` in `ApplicationController` to catch
  missing authorization checks.

### Roles

- **Household roles** live on `Membership.role`: `head`, `adult`, `child`.
  A person's role depends on which household they're in.
- **Platform staff**: `identities.staff` (boolean). Madmin and impersonation
  only; staff get no special access to households.

### Policy Pattern

Policies receive the current **membership**, not a user. `pundit_user` returns
`Current.membership`, which is nil outside household URLs; policies for actions
outside a household must not read it.

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :membership, :record

  def initialize(membership, record)
    @membership = membership
    @record = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def update?  = false
  def destroy? = false

  private
    def member? = membership&.active?
    def head?   = member? && membership.head?
end
```

```ruby
# app/policies/membership_policy.rb
class MembershipPolicy < ApplicationPolicy
  def create? = head?
end
```

### Scoping

- Household resources belong to `Household` and are always reached through
  `Current.household` (`Current.household.memberships.find(id)`).
- Personal resources belong to `User` and are reached through `Current.user`.
- A record from another household must 404, never 403.
- There is no "admin sees everything" scope; staff use Madmin.

---

## UUIDv7 Primary Keys

- All tables use UUIDv7 as the primary key. No auto-incrementing integers.
- Generated via `SecureRandom.uuid_v7` (Ruby 3.3+ stdlib) in a
  `before_create` callback on `ApplicationRecord`.
- All foreign keys are `:uuid` type.
- All migrations use `id: :uuid` and `type: :uuid` for references.

---

## AI Integration (RubyLLM)

- AI features are model methods, not service objects.
- Use `acts_as_chat` and `acts_as_message` ActiveRecord mixins.
- Streaming responses via RubyLLM's built-in streaming support.
- AI configuration in `config/initializers/ruby_llm.rb`.

---

## Background Jobs

- Solid Queue (Rails 8 default, DB-backed). No Redis required for jobs.
- Job naming convention: `_later` for enqueuing, `_now` for synchronous.
  ```ruby
  class NotificationJob < ApplicationJob
    def perform(notification)
      notification.deliver_now
    end
  end

  # Enqueue:
  notification.deliver_later
  ```

---

## Testing

- **Minitest + Fixtures.** No RSpec, no Factory Bot.
- Fixtures for test data. Keep them minimal and meaningful.
- **Coverage is 100% (lines), enforced by SimpleCov** on a full
  `bin/rails test:all` run. No new filters or `# :nocov:` without Casey's approval.
- **Test database constraints with `insert!` or `update_column`** so the test
  proves the database, not the validation. One violating statement per test, last.
- **Component tests** in `test/components/` using `ViewComponent::TestCase`
  with `render_inline` and `assert_selector`. Test every meaningful state.
- **Policy tests** in `test/policies/` — test each role's access for every policy.
- **System tests** with Capybara + Selenium (headless Chrome).
- **Accessibility tests** — call `assert_accessible` in system tests to run
  axe-core checks. Every page should be checked for accessibility violations.
  ```ruby
  test "dashboard is accessible" do
    visit dashboard_url
    assert_accessible
  end
  ```
- Test through the public interface (request tests, model tests, component tests, policy tests).
- Run the full suite: `bin/rails test:all`

### Accessibility

- All views must include proper `lang` attribute on `<html>`.
- All page content must be inside landmark elements (`<main>`, `<nav>`, `<header>`, `<footer>`).
- All images must have `alt` attributes.
- All form inputs must have associated labels.
- axe-core runs automatically in system tests via `assert_accessible` helper.
- CI catches accessibility regressions on every push.

---

## Anti-Patterns — Do NOT Use

These are explicitly forbidden in this codebase:

| Anti-Pattern | Why |
|---|---|
| `app/services/` directory | Business logic belongs in models/POROs |
| Service objects with `.call` | Name methods for what they do |
| Custom authentication | We use Devise — don't reinvent auth |
| `current_user`, `authenticate_user!`, `sign_in(:user, …)` | Devise is on `Identity`: `current_identity`, `authenticate_identity!` |
| A role column on `User` | Household roles live on `Membership`; platform staff on `identities.staff` |
| `Household.find(params[:household_id])` | Look up through `Current.user` so non-members get a 404 |
| Analytics and tracking gems (Ahoy, third-party trackers) | Aglowy keeps no tracking |
| CanCanCan | We use Pundit for authorization |
| Account/team multitenancy (subdomains, `Account` models) | The family unit is `Household`; scope by `/:household_id` and `Membership` |
| RSpec | We use Minitest + Fixtures |
| Factory Bot | We use Fixtures |
| React / Vue / HTMX | We use Hotwire (Turbo + Stimulus) |
| GraphQL | We use standard Rails controllers + Turbo |
| Tailwind CSS | We use Primer + Sass |
| Hand-rolled buttons/forms/banners | Use the Primer component |
| Form markup by hand (`form_with` + `f.text_field`) | A Primer form class in `app/forms/`, rendered with `primer_form_with` |
| Phlex | We use ViewComponent with sidecar ERB |
| Redis (for jobs) | We use Solid Queue (DB-backed) |
| Sidekiq | We use Solid Queue |
| `jbuilder` | We don't serve JSON APIs |
| Integer primary keys | All PKs are UUIDv7 |
| Boolean state columns | Use state-as-records pattern (exception: `memberships.active`, decided Nov 2026) |
| `before_save` for business logic | Use explicit model methods |
| Presenters / Decorators | Use ViewComponent or helpers |
| Inline styles / magic numbers | Use Primer primitives, utilities, and BEM classes |
| God models | Extract concerns, not services |
| Missing `authorize` calls | Every controller action must authorize via Pundit |
| Cypress / Playwright | We use Capybara + Selenium for system tests |
| Views without landmarks | All page content must be in `<main>`, `<nav>`, etc. |

---

## Naming Conventions

- **Concerns**: Adjectives — `Closeable`, `Watchable`, `Assignable`, `Billable`
- **Controllers**: Noun-based, nested — `Cards::ClosuresController`
- **Components**: `{Name}Component` — `PlanCardComponent`, `BadgeComponent`
- **Component files**: `app/components/plan_card_component.rb` + `.html.erb` sidecar
- **Policies**: `{Model}Policy` — `ProjectPolicy`, `UserPolicy` in `app/policies/`
- **CSS classes**: BEM — `.plan-card`, `.plan-card__header`, `.plan-card--featured`
- **Sass files**: One per component — `components/_plan_card.scss`
- **Jobs**: `_later` / `_now` suffix convention
- **Scopes**: `preloaded` for eager loading, descriptive names for filters
- **Methods**: Intention-revealing — `order.fulfill`, `membership.deactivate`
  not `order.process` or `membership.update_role`

---

## Iterating This Document

After Claude makes a mistake or follows the wrong pattern, add a rule here.
End corrections with: *"Update CLAUDE.md so you don't make that mistake again."*

This document evolves with the codebase. Ruthlessly edit it.