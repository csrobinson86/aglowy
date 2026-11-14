require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  test "the household home passes assert_accessible as a head" do
    sign_in identities(:head)

    visit household_root_url(household_id: households(:home))

    assert_selector "h1", text: "Home"
    assert_link "Add a member"
    assert_accessible
    capture_screens("home-head")
  end

  test "the household home passes assert_accessible as a child" do
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)

    visit household_root_url(household_id: households(:home))

    assert_selector "h2", text: "Welcome to The Head Family"
    assert_no_link "Add a member"
    assert_accessible
    capture_screens("home-child")
  end
end
