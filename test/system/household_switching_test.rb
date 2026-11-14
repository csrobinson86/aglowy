require "application_system_test_case"

class HouseholdSwitchingTest < ApplicationSystemTestCase
  test "the two-household person lands on the chooser, opens one, switches to the other" do
    visit new_identity_session_url
    fill_in "Email", with: identities(:head).email
    fill_in "Password", with: "password123"
    click_on "Log in"
    assert_selector "h1", text: "Your households"

    within("main") { click_on "The Head Family" }
    assert_selector "h1", text: "The Head Family"
    assert_turbo_idle

    find("summary", text: "Switch household").click
    capture_screens("household-switcher")
    click_on "The Grandparent Family"
    assert_selector "h1", text: "The Grandparent Family"
  end

  test "every page on the way passes assert_accessible" do
    sign_in identities(:head)

    {
      "households" => households_url,
      "new-household" => new_household_url,
      "dashboard" => household_root_url(household_id: households(:home)),
      "dashboard-second-household" => household_root_url(household_id: households(:parents))
    }.each do |name, url|
      visit url
      assert_selector "h1"
      assert_accessible
      capture_screens(name)
    end
  end
end
