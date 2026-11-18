require "application_system_test_case"

# Start a daily brief from a starter plan, and see the plan it made (docs/design/daily-brief.md, Start and Your plan;
# frames brief-start.png and brief-plan.png). Nothing here calls an AI provider: no brief is made yet.
class DailyBriefPlanTest < ApplicationSystemTestCase
  setup do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
  end

  test "start from A husband and father, and land on the plan with its five focus areas and the week" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    within("aside") { click_on "Daily brief" }

    assert_selector "h1", text: "Start your day with a daily brief"
    assert_selector "aside nav [aria-current=page]", text: "Daily brief"
    assert_text "Written by AI, from jw.org and wol.jw.org"
    assert_accessible
    choose "A husband and father"
    capture_screens("brief-start")

    click_on "Start my daily brief"

    assert_selector "h1", text: "Your plan"
    within("section[aria-labelledby=focus-areas]") do
      assert_selector "li", count: 5
      assert_text "As a husband"
      assert_text "Growing appreciation for Jehovah"
      assert_link "1 Timothy 3:8-13"
    end
    within("section[aria-labelledby=week]") do
      assert_selector "tbody tr", count: 7
      assert_selector "tbody th", text: "Today", count: 1
      assert_text "The brief chooses"
    end
    assert_text "Ready by 5:00 AM"
    assert_text "What's sent to the AI"
    assert_accessible
    capture_screens("brief-plan")
    capture_screens("brief-plan-sections", scroll_to: "#whats-sent")
  end
end
