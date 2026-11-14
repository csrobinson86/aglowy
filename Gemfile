source "https://rubygems.org"

ruby "~> 4.0.9"

# ─── Framework ────────────────────────────────────────────────────────────────
gem "rails", "~> 8.1.3"
gem "propshaft"                   # Modern asset pipeline (Rails 8 default)
gem "bootsnap", require: false    # Reduces boot times through caching

# ─── Database ─────────────────────────────────────────────────────────────────
# PostgreSQL with UUIDv7 primary keys via SecureRandom.uuid_v7 (Ruby 3.3+).
gem "pg", "~> 1.1"

# ─── Server ───────────────────────────────────────────────────────────────────
gem "puma", ">= 5.0"
gem "thruster", require: false    # HTTP/2 proxy, asset caching/compression
gem "kamal", require: false       # Docker-based deployment

# ─── Frontend ─────────────────────────────────────────────────────────────────
# Hotwire: Turbo for page transitions, Stimulus for JS sprinkles.
# No React, no HTMX, no GraphQL.
gem "turbo-rails"
gem "stimulus-rails"
gem "jsbundling-rails"            # esbuild for JavaScript bundling
gem "dartsass-rails"              # Standalone Dart Sass binary — no Node needed for CSS

# ─── Components ───────────────────────────────────────────────────────────────
# Testable, reusable view components with sidecar ERB templates.
# Design system components live in app/components/ with co-located templates.
gem "view_component"
# GitHub's Primer design system as ViewComponents. Pinned exactly: pre-1.0,
# breaking changes land in patch releases. Keep in lockstep with the
# @primer/view-components npm package. In maintenance mode since Feb 2026.
gem "primer_view_components", "0.53.5"

# ─── Background Jobs & Infrastructure ────────────────────────────────────────
# Rails 8 defaults. All DB-backed, no Redis required.
gem "solid_queue"                 # Background jobs
gem "solid_cache"                 # Caching
gem "solid_cable"                 # Action Cable adapter
gem "mission_control-jobs"        # Web UI for Solid Queue

# ─── AI ───────────────────────────────────────────────────────────────────────
# Unified API for OpenAI + Anthropic. Streaming support, acts_as_chat and
# acts_as_message ActiveRecord mixins, Rails generator for chat UI.
gem "ruby_llm"

# ─── Admin ────────────────────────────────────────────────────────────────────
# Lightweight Rails admin engine by Chris Oliver (GoRails).
gem "madmin"

# ─── Auth & Authorization ────────────────────────────────────────────────────
gem "devise"
gem "pundit"

# ─── Logging ──────────────────────────────────────────────────────────────────
# Structured, single-line JSON logs. Production-ready by default.
# Enable in dev with LOGRAGE_IN_DEVELOPMENT=true in .env.development.
gem "lograge"

# ─── Platform ─────────────────────────────────────────────────────────────────
gem "tzinfo-data", platforms: %i[windows jruby]

# ─── Development & Test ──────────────────────────────────────────────────────
group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails"                    # Load environment variables from .env files
  gem "bundler-audit", require: false   # Audit gems for known security defects
  gem "brakeman", require: false        # Static analysis for security vulnerabilities
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "axe-core-capybara"
  gem "axe-core-api"
end
