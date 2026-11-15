require "application_system_test_case"

class ScheduleGoalStepTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 14, 12) }

  test "schedule Read Luke together, come back to the goal, follow the study link" do
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))
    assert_accessible
    capture_screens("goal-schedulable")

    within("##{dom_id(goal_steps(:read_luke))}") { click_on "Schedule as a family study" }

    assert_selector "h1", text: "Schedule a family study"
    assert_field "What will you study?", with: "Read Luke together"
    assert_field "Date", with: "2027-02-15"
    assert_accessible
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    click_on "Schedule study"

    assert_text "The study is scheduled and linked to this step."
    assert_selector "h1", text: "Read the four Gospels together"
    within("##{dom_id(goal_steps(:read_luke))}") do
      assert_no_link "Schedule as a family study"
      assert_link "Family study · Mon, Feb 15"
    end
    within("##{dom_id(goal_steps(:read_john))}") { assert_link "Schedule as a family study" }
    assert_accessible
    capture_screens("goal-step-linked", scroll_to: "##{dom_id(goal_steps(:read_luke))}")

    within("##{dom_id(goal_steps(:read_luke))}") { click_on "Family study · Mon, Feb 15" }

    assert_selector "h1", text: "Read Luke together"
    assert_text "Monday, February 15, 2027"
    assert_accessible
  end

  private
    def dom_id(...)
      ActionView::RecordIdentifier.dom_id(...)
    end
end
