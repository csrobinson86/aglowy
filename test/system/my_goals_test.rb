require "application_system_test_case"

class MyGoalsTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 14, 12) }

  test "create a personal goal, add and tick steps, complete it" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    within("nav[aria-label='Main']") { click_on "My goals" }
    assert_selector "h1", text: "My goals"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "My goals"
    assert_selector ".blankslate h2", text: "No goals of your own yet"
    assert_accessible
    capture_screens("my-goals-empty")

    click_on "New goal", match: :first
    assert_selector "h1", text: "New goal"
    fill_in "Title", with: "Read the Psalms"
    fill_in "Why this goal? (optional)", with: "To learn to pray from the heart."
    fill_in "Target date", with: Date.new(2027, 2, 28)
    click_on "Create goal"

    assert_text "Goal created."
    assert_selector "h1", text: "Read the Psalms"
    assert_selector "h1 .Label", text: "Private"
    assert_selector "nav[aria-label='Breadcrumb']", text: "My goals"
    assert_text "Target February 28, 2027"
    assert_no_text "Set by"
    assert_no_field "For"

    add_step "Read Psalms 1 to 50"
    add_step "Read Psalms 51 to 100"
    assert_text "0 of 2 steps done"

    check "Mark Read Psalms 1 to 50 done"
    assert_text "1 of 2 steps done"
    assert_text "Done · Nov 14"
    assert_no_text "Every step is done. Mark the goal complete?"
    assert_no_link "Schedule as a family study"
    assert_accessible
    capture_screens("my-goals")

    check "Mark Read Psalms 51 to 100 done"
    assert_text "2 of 2 steps done"
    within(".Banner", text: "Every step is done. Mark the goal complete?") { click_on "Mark goal complete" }

    assert_text "Goal marked complete."
    assert_text "Completed on November 14 by Hannah Head."
    assert_no_selector "#goal-steps input[type=checkbox]"

    within("nav[aria-label='Breadcrumb']") { click_on "My goals" }
    assert_selector "h1", text: "My goals"
    within("nav[aria-label='Goals']") { click_on "Completed" }
    within("main .Box") { assert_text "Read the Psalms" }
    assert_accessible
    capture_screens("my-goals-completed")
  end

  private
    def add_step(title)
      within("#new-goal-step") do
        fill_in "New step", with: title
        click_on "Add step"
      end
      within("#goal-steps") { assert_text title }
    end
end
