require "application_system_test_case"

class GoalPageTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 14, 12) }

  test "add, edit and remove a step without a full reload" do
    sign_in identities(:spouse)
    visit household_goals_url(household_id: households(:home))
    click_on "Read the four Gospels together"

    assert_selector "h1", text: "Read the four Gospels together"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Family goals"
    assert_text "3 of 7 steps done"
    assert_text "Eli Child · 4 of 6"
    assert_accessible
    capture_screens("goal")
    page.execute_script("window.stillTheSamePage = true")

    within("#new-goal-step") do
      fill_in "New step", with: "Memorize John 3:16"
      check "Eli Child"
      check "Sofia Child"
      fill_in "Due (optional)", with: Date.new(2027, 3, 1)
      click_on "Add step"
    end

    within("#goal-steps") { assert_text "Memorize John 3:16" }
    assert_text "3 of 8 steps done"
    assert_text "Eli Child · 4 of 7"
    within("#new-goal-step") { assert_field "New step", with: "" }

    click_on "Edit step: Find three parables and explain one"
    within("##{dom_id(goal_steps(:parables))}") do
      assert_field "Title", with: "Find three parables and explain one"
      uncheck "Eli Child"
      assert_text "Changing who this is for clears 1 tick."
      check "Eli Child"
      assert_no_text "Changing who this is for clears"
      uncheck "Sofia Child"
      assert_no_text "Changing who this is for clears"
      assert_accessible
      capture_screens("goal-edit-step", scroll_to: "##{dom_id(goal_steps(:parables))}")
      fill_in "Title", with: "Find a parable and explain it"
      click_on "Save"
    end

    within("#goal-steps") do
      assert_text "Find a parable and explain it"
      assert_text "Eli Child · Done by Eli Child · Jan 25"
    end
    assert_text "4 of 8 steps done"

    click_on "Edit step: Memorize John 3:16"
    within("##{dom_id(Goal::Step.find_by!(position: 8, goal: goals(:gospels)))}") do
      click_on "Cancel"
    end
    assert_no_field "Title"

    click_on "Edit step: Memorize John 3:16"
    click_on "Remove step: Memorize John 3:16"
    within("#goal-steps") { assert_no_text "Memorize John 3:16" }
    assert_text "4 of 7 steps done"

    assert page.evaluate_script("window.stillTheSamePage"), "expected Turbo to update the page in place"
  end

  test "edit the goal" do
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))

    click_on "Edit"
    assert_selector "h1", text: "Edit goal"
    assert_accessible
    fill_in "Title", with: "Read the Gospels together"
    click_on "Save"

    assert_text "Goal updated."
    assert_selector "h1", text: "Read the Gospels together"
  end

  private
    def dom_id(...)
      ActionView::RecordIdentifier.dom_id(...)
    end
end
