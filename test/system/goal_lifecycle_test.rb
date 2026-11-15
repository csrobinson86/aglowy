require "application_system_test_case"

class GoalLifecycleTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 14, 12) }

  test "complete from the Banner, archive, restore, and delete another through the Dialog" do
    goal = households(:home).goals.create!(title: "Read Jonah together", target_on: Date.new(2027, 1, 31), set_by: users(:spouse))
    goal.add_step(title: "Read Jonah 1 and 2").tick(for: nil, by: users(:spouse))
    goal.add_step(title: "Read Jonah 3 and 4")
    sign_in identities(:spouse)

    visit household_goal_url(household_id: households(:home), id: goals(:gospels))
    open_goal_menu
    assert_selector "[role=menuitem]", text: "Mark goal complete"
    assert_selector "[role=menuitem]", text: "Archive"
    assert_selector "[role=menuitem]", text: "Delete goal…"
    assert_accessible
    capture_screens("goal-menu")
    find("body").send_keys(:escape)
    assert_no_selector "[role=menu]"

    visit household_goal_url(household_id: households(:home), id: goal)
    check "Mark Read Jonah 3 and 4 done"
    within(".Banner", text: "Every step is done. Mark the goal complete?") { click_on "Mark goal complete" }

    assert_text "Goal marked complete."
    assert_text "Completed on November 14 by Sam Spouse."
    assert_no_selector "#goal-steps input[type=checkbox]"
    assert_no_selector "#new-goal-step"
    assert_accessible
    capture_screens("goal-completed")

    click_on "Family goals", match: :first
    click_on "Completed"
    within("main .Box") { assert_text "Read Jonah together" }

    click_on "Read Jonah together"
    open_goal_menu
    find("[role=menuitem]", text: "Archive").click

    assert_text "Goal archived."
    assert_selector "nav[aria-label='Goals'] a[aria-current='page']", text: "Archived"
    within("main .Box") { assert_text "Read Jonah together" }

    click_on "Read Jonah together"
    assert_text "Completed on November 14 by Sam Spouse. Archived on November 14 by Sam Spouse."
    within(".Banner") { click_on "Restore" }

    assert_text "Goal restored."
    assert_text "Completed on November 14 by Sam Spouse."
    click_on "Family goals", match: :first
    click_on "Completed"
    within("main .Box") { assert_text "Read Jonah together" }

    visit household_goal_url(household_id: households(:home), id: goals(:gospels))
    open_goal_menu
    find("[role=menuitem]", text: "Delete goal…").click
    within("dialog[open]") do
      assert_selector "h1", text: "Delete this goal?"
      assert_text "Its steps and progress are deleted too. Archive it instead to keep it for looking back."
    end
    assert_accessible
    capture_screens("goal-delete-dialog")
    within("dialog[open]") { click_on "Delete goal" }

    assert_text "Goal deleted."
    assert_selector "h1", text: "Family goals"
    assert_no_text "Read the four Gospels together"
  end

  test "cancel leaves the goal alone" do
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))

    open_goal_menu
    find("[role=menuitem]", text: "Delete goal…").click
    within("dialog[open]") { click_on "Cancel" }

    assert_no_selector "dialog[open]"
    assert_selector "h1", text: "Read the four Gospels together"
    assert Goal.exists?(goals(:gospels).id)
  end

  private
    def open_goal_menu
      find("button[aria-label='Goal actions']").click
      assert_selector "[role=menu]"
    end
end
