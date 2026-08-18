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

## Stack

- Ruby 4.0.x / Rails 8.1
- PostgreSQL with UUIDv7 primary keys
- Devise for authentication
- Pundit for authorization (admin / user roles)
- Hotwire (Turbo + Stimulus) for frontend — no React, no HTMX, no GraphQL
- Sass via `dartsass-rails` (standalone binary, no Node dependency for CSS)
- ViewComponent for reusable UI components
- esbuild for JavaScript bundling (Yarn for package management)
- RubyLLM for AI (OpenAI + Anthropic, streaming)
- Solid Queue / Cache / Cable for background jobs, caching, Action Cable (DB-backed, no Redis)
- Ahoy + MaxMind for analytics
- Pay + Stripe for billing
- Madmin for admin (locked to admin role)
- Minitest + Fixtures for testing
- Capybara + Selenium for system tests
- axe-core for automated accessibility testing
- dotenv-rails for environment variables (development/test only)
- letter_opener for email previews in development
- Kamal 2 for deployment

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
  what they do: `order.fulfill`, `user.upgrade_to_admin`.
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
- **Madmin** is locked to admin users via `authenticate_admin_user` in
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

### CSS & Design System

- **Sass** via `dartsass-rails`. No Tailwind, no CSS-in-JS.
- Design tokens (colors, spacing, type scale, radii, shadows) live in
  `app/assets/stylesheets/design_system/_tokens.scss`.
- Shared patterns live in mixins (`_mixins.scss`). Use mixins for repeated
  multi-property patterns (e.g., `@include card-base`, `@include button-primary`).
- Component styles use **BEM naming**: `.plan-card`, `.plan-card__header`,
  `.plan-card--featured`. One `.scss` file per component in
  `app/assets/stylesheets/components/`.
- `application.scss` is `@use` imports only — no loose styles.
- Never use inline styles. Never use arbitrary magic numbers for spacing,
  font sizes, or colors — always reference design tokens.
- Build a **living style guide** (`/design_system` route in development)
  to document available components and tokens.

---

## Authentication (Devise)

- **Devise** handles all authentication. Do not roll custom auth.
- Modules enabled: `database_authenticatable`, `registerable`, `recoverable`,
  `rememberable`, `validatable`, `confirmable`, `lockable`.
- Devise views are generated into the app for customization:
  ```bash
  bin/rails generate devise:views
  ```
- User model:
  ```ruby
  class User < ApplicationRecord
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :validatable,
           :confirmable, :lockable

    enum :role, { user: "user", admin: "admin" }, default: "user"
  end
  ```
- `Current.user` set via `CurrentAttributes` for access outside controllers.

---

## Authorization (Pundit)

- **Pundit** handles all authorization via policy objects in `app/policies/`.
- Every controller that accesses resources must call `authorize @record`.
- Use `after_action :verify_authorized` in `ApplicationController` to catch
  missing authorization checks.

### Roles

Two roles, stored as an enum on `User`:
- **user** — default. Signed-up customers. Can only access their own resources.
- **admin** — platform operators. Full access, Madmin admin panel.

### Policy Pattern

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def update?  = false
  def destroy? = false

  private

  def admin?
    user.admin?
  end

  def owner?
    record.respond_to?(:user) && record.user == user
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if @user.admin?
        @scope.all
      else
        @scope.where(user: @user)
      end
    end
  end
end
```

```ruby
# app/policies/project_policy.rb
class ProjectPolicy < ApplicationPolicy
  def show?
    admin? || record.user == user
  end

  def update?
    admin? || record.user == user
  end

  def destroy?
    admin?
  end
end
```

### Scoping

- Individual user resources `belong_to :user`.
- Controllers scope queries through `Current.user` or Pundit scopes:
  ```ruby
  @projects = policy_scope(Project)
  ```
- Admins see everything. Users see only their own resources.

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
- Run the full suite: `bin/rails test && bin/rails test:system`

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
| CanCanCan | We use Pundit for authorization |
| Team-based multitenancy | Individual user accounts, not teams |
| RSpec | We use Minitest + Fixtures |
| Factory Bot | We use Fixtures |
| React / Vue / HTMX | We use Hotwire (Turbo + Stimulus) |
| GraphQL | We use standard Rails controllers + Turbo |
| Tailwind CSS | We use Sass with a custom design system |
| Phlex | We use ViewComponent with sidecar ERB |
| Redis (for jobs) | We use Solid Queue (DB-backed) |
| Sidekiq | We use Solid Queue |
| `jbuilder` | We don't serve JSON APIs |
| Integer primary keys | All PKs are UUIDv7 |
| Boolean state columns | Use state-as-records pattern |
| `before_save` for business logic | Use explicit model methods |
| Presenters / Decorators | Use ViewComponent or helpers |
| Inline styles / magic numbers | Use design tokens and BEM classes |
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
- **Methods**: Intention-revealing — `order.fulfill`, `user.upgrade_to_admin`
  not `order.process` or `user.update_role`

---

## Iterating This Document

After Claude makes a mistake or follows the wrong pattern, add a rule here.
End corrections with: *"Update CLAUDE.md so you don't make that mistake again."*

This document evolves with the codebase. Ruthlessly edit it.