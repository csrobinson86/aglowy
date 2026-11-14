require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "the root page is accessible" do
    visit root_url
    assert_accessible
    capture_screens("root")
  end
end
