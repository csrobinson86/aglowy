  # Aglowy

  Rails 8.1 SaaS template. Start from kin.

  ## Requirements

  - Ruby 4.0.1
  - Rails 8.1
  - PostgreSQL
  - Node.js + Yarn (for esbuild JS bundling)

  ## Quick Start

  ```bash
  bin/setup
  bin/dev
  ```

  Visit `http://localhost:3000`.

  ## Starting a New Project From This Template

  ```bash
  git clone https://github.com/Kinsley-Analytics/Aglowy.git my_new_app
  cd my_new_app
  rm -rf .git && git init
  bin/rename my_new_app
  bin/setup
  bin/dev
  ```

  ## Stack

  - **Ruby 4.0.x / Rails 8.1** — latest stable
  - **PostgreSQL** — UUIDv7 primary keys via `SecureRandom.uuid_v7`
  - **Devise** — authentication (confirmable, lockable)
  - **Pundit** — authorization via policy objects (admin / user roles)
  - **Hotwire** (Turbo + Stimulus) — server-rendered HTML, no React/HTMX
  - **Sass** via dartsass-rails — standalone binary, no Node dependency for CSS
  - **ViewComponent** — testable, reusable UI components with sidecar ERB
  - **Solid Queue / Cache / Cable** — Rails 8 defaults, DB-backed, no Redis
  - **Madmin** — admin panel (locked to admin users)
  - **Propshaft** — asset pipeline
  - **Kamal 2** — deployment
  - **Minitest + Fixtures** — testing
  - **Capybara + Selenium** — system tests
  - **axe-core** — automated accessibility testing

  ## Architecture

  This template follows the 37signals/DHH "vanilla Rails is plenty" philosophy. Business logic lives in models and POROs, never in service objects. See `CLAUDE.md` for the complete architectural guide.

  ## Auth

  Devise handles authentication. Pundit handles authorization with two roles:

  - **user** — default. Signed-up customers. Access their own resources.
  - **admin** — platform operators. Full access, Madmin admin panel at `/madmin`.

  Admins can impersonate any user via `Admin::ImpersonationsController` to debug issues from the user's perspective. A banner displays during impersonation with a stop button to return to the admin account.

  ## Design System

  Sass design system with BEM naming in `app/assets/stylesheets/design_system/`:

  - `_tokens.scss` — spacing, type scale, colors, radii, shadows, breakpoints
  - `_mixins.scss` — reusable patterns (`@include card`, `@include button-primary`, etc.)
  - `_reset.scss` — minimal modern CSS reset

  Component styles in `app/assets/stylesheets/components/`, one file per ViewComponent.

  Living style guide available in development at `/design_system`.

  ## Database

  PostgreSQL with UUIDv7 primary keys on all tables:

  ```bash
  bin/rails db:prepare
  ```

  ## Tests

  ```bash
  bin/rails test              # Unit, integration, and component tests
  bin/rails test:system       # System tests with accessibility checks
  bin/ci                      # Full CI suite (lint, security, tests)
  ```

  System tests include `assert_accessible` for automated accessibility checking via axe-core.

  ## Per-Project Setup

  These gems are included but need generators run per project:

  ```bash
  bin/rails generate ahoy:install       # Analytics (check migration for UUIDs)
  bin/rails generate pay:install        # Billing (configure Stripe keys in .env)
  bin/rails generate ruby_llm:install   # AI chat (OpenAI + Anthropic)
  ```

  ## Key Directories

  ```
  app/components/               # ViewComponent classes + sidecar ERB
  app/assets/stylesheets/
    design_system/              # Tokens, mixins, reset
    components/                 # One .scss per component (BEM)
    layouts/                    # Layout-level styles
  app/models/concerns/          # Concerns as adjectives (Closeable, Billable)
  app/policies/                 # Pundit policy objects
  app/madmin/                   # Madmin admin resources
  test/components/              # ViewComponent tests
  test/policies/                # Policy tests
  test/system/                  # System tests with accessibility
  test/support/                 # Test helpers (accessibility_helper.rb)
  ```

  ## Scripts

  - `bin/setup` — install dependencies, create database, run migrations
  - `bin/dev` — start Rails server + asset watchers
  - `bin/ci` — full CI suite (setup, lint, security scan, tests)
  - `bin/rename <new_name>` — rename the app for a new project
  - `bin/recreate` — rebuild the template from a fresh `rails new` (for Rails upgrades)

  ## License

  MIT