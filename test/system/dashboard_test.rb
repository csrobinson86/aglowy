require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  test "the household page passes assert_accessible" do
    sign_in identities(:head)

    visit household_root_url(household_id: households(:home))

    assert_text "The Head Family"
    assert_accessible
  end
end
