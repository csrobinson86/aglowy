require "test_helper"
require "axe/matchers/be_axe_clean"
require_relative "support/accessibility_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AccessibilityHelper
  include Devise::Test::IntegrationHelpers

  # Fixture passwords are in breach lists, so after a real sign-in Chrome's
  # password manager opens a leak warning that swallows every later click.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
  end

  # The full suite runs in parallel workers, so pages can take longer than the 2s default.
  Capybara.default_max_wait_time = 5

  # Turbo marks <html aria-busy> until a visit completes and may move focus as
  # it finishes, which closes an open menu. Wait for it before interacting.
  def assert_turbo_idle
    assert_selector "html:not([aria-busy])"
  end
end
