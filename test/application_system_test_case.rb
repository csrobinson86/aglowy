require "test_helper"
require "axe/matchers/be_axe_clean"
require_relative "support/accessibility_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include AccessibilityHelper
  include Devise::Test::IntegrationHelpers

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
