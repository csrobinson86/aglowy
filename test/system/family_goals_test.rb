require "application_system_test_case"

class FamilyGoalsTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 14, 12) }

  test "switch tabs" do
    sign_in identities(:spouse)
    visit household_root_url(household_id: households(:home))

    within("nav[aria-label='Main']") { click_on "Family goals" }
    assert_selector "h1", text: "Family goals"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Family goals"
    assert_selector "nav[aria-label='Goals'] a[aria-current='page']", text: "Active"
    assert_text "Goals the family is working on now."
    assert_text "3 of 7 steps"
    assert_accessible
    capture_screens("family-goals")

    within("nav[aria-label='Goals']") { click_on "Completed" }
    assert_selector "nav[aria-label='Goals'] a[aria-current='page']", text: "Completed"
    assert_text "Read Proverbs together"
    assert_text "Marked complete by Sam Spouse"
    assert_no_text "Read the four Gospels together"

    within("nav[aria-label='Goals']") { click_on "Archived" }
    assert_selector "nav[aria-label='Goals'] a[aria-current='page']", text: "Archived"
    assert_text "Learn the new songs"
    assert_text "Archived by Sam Spouse"
    assert_accessible
    capture_screens("family-goals-archived")
  end

  test "a child sees an empty Completed tab, and no New goal button" do
    goals(:proverbs).destroy
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    visit household_goals_url(household_id: households(:home), status: "completed")

    assert_selector ".blankslate h2", text: "Nothing completed yet"
    assert_no_link "New goal"
    assert_accessible
    capture_screens("family-goals-empty")
  end

  test "create a goal" do
    sign_in identities(:spouse)
    visit household_goals_url(household_id: households(:home))

    click_on "New goal"
    assert_selector "h1", text: "New family goal"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Family goals"
    assert_text "You'll add the steps next, on the goal's page."
    assert_accessible
    capture_screens("new-goal")

    click_on "Create goal"
    assert_selector ".FormControl-inlineValidation", text: "can't be blank"
    assert_accessible

    fill_in "Title", with: "Read Acts together"
    fill_in "Why this goal? (optional)", with: "To see how the early Christians preached."
    fill_in "Target date", with: Date.new(2027, 6, 30)
    click_on "Create goal"

    assert_text "Goal created."
    assert_selector "h1", text: "Read Acts together"
    assert_text "Target June 30, 2027 · Set by Sam Spouse"
    assert_selector "#goal-progress h2", text: "No steps yet"

    within("nav[aria-label='Breadcrumb']") { click_on "Family goals" }
    assert_selector "nav[aria-label='Goals'] a[aria-current='page']", text: /Active\s*2/
    assert_text "Read Acts together"
    assert_text "Target Jun 30, 2027"
    assert_text "No steps yet"
  end
end
