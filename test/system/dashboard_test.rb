require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  test "the household home passes assert_accessible as a head" do
    households(:home).family_studies.destroy_all
    sign_in identities(:head)

    visit household_root_url(household_id: households(:home))

    assert_selector "h1", text: "Home"
    assert_link "Add a member"
    assert_accessible
    capture_screens("home-head")
  end

  test "the household home passes assert_accessible as a child" do
    households(:home).family_studies.destroy_all
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)

    visit household_root_url(household_id: households(:home))

    assert_selector "h2", text: "Welcome to The Head Family"
    assert_no_link "Add a member"
    assert_accessible
    capture_screens("home-child")
  end

  test "the household home with sessions passes assert_accessible" do
    family_study_sessions(:weekly_next).update!(scheduled_at: family_study_sessions(:weekly_next).scheduled_at + 4.days)
    sign_in identities(:head)

    visit household_root_url(household_id: households(:home))

    assert_selector "h2", text: "Next family study"
    assert_selector "h3", text: "Draw Close to Jehovah, chapter 1"
    assert_selector "h2", text: "Coming up"
    assert_link "All family studies"
    assert_accessible
    capture_screens("home-with-studies")
  end
end
