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

  # Today's row and "The brief chooses" are custom colours, and the week scrolls in its own box on a phone.
  test "both pages pass assert_accessible in dark and at phone width" do
    sign_in identities(:head)
    users(:head).update!(appearance: "dark")
    plan_url = household_daily_brief_plan_url(household_id: households(:home))
    start_url = new_household_daily_brief_plan_url(household_id: households(:home))

    visit start_url
    assert_selector "body[data-color-mode='dark'] h1", text: "Start your day with a daily brief"
    assert_accessible
    DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    visit plan_url
    assert_selector "body[data-color-mode='dark'] h1", text: "Your plan"
    assert_accessible

    users(:head).update!(appearance: "auto")
    page.driver.browser.manage.window.resize_to(390, 844)
    visit plan_url
    assert_selector "h1", text: "Your plan"
    assert_accessible
    users(:head).daily_brief_plan.destroy!
    visit start_url
    assert_selector "h1", text: "Start your day with a daily brief"
    assert_accessible
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
