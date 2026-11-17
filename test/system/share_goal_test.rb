require "application_system_test_case"

class ShareGoalTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 14, 12) }

  test "share a goal through the Dialog, and another member reads it from the Shared tab" do
    goal = goals(:spouse_bible_reading)
    goal.add_step(title: "Read Genesis", due_on: Date.new(2026, 12, 31))
    goal.add_step(title: "Read Exodus")
    goal.steps.first.tick(for: nil, by: users(:spouse))

    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goal)
    assert_selector "h1 .Label", text: "Private"

    click_on "Share with household"
    within("dialog[open]") do
      assert_selector "h1", text: "Share with The Head Family?"
      assert_text "Members of The Head Family will be able to read this goal and its steps. They can't change it."
      assert_text "You can stop sharing at any time, and if you leave The Head Family it stops automatically."
    end
    wait_for_dialog # axe reads the Share goal button's colour mid-animation otherwise
    assert_accessible
    capture_screens("share-goal")

    within("dialog[open]") { click_on "Share goal" }
    assert_text "Shared with The Head Family."
    assert_no_selector "dialog[open]"
    assert_selector "h1 .Label", text: "Shared with The Head Family"
    assert_button "Stop sharing"
    capture_screens("share-goal-shared")

    sign_out :identity
    sign_in identities(:head)
    visit household_my_goals_url(household_id: households(:home))
    within("nav[aria-label='Goals']") { click_on "Shared in this household" }
    within("main .Box") { assert_text "Shared by Sam Spouse" }
    assert_accessible
    capture_screens("my-goals-shared")
    within("main .Box") { click_on "Read the whole Bible in a year" }

    assert_selector "h1", text: "Read the whole Bible in a year"
    assert_selector "h1 .Label", text: "Shared by Sam Spouse"
    assert_text "1 of 2 steps done"
    assert_text "Read Genesis"
    assert_no_selector "main input, main button"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "My goals"
    assert_accessible
    capture_screens("shared-goal")
  end
end
