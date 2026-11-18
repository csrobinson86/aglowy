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

  test "add In the ministry from its chip, edit its scriptures and delete it; then turn off For the children and set 6:00 AM" do
    plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    sign_in identities(:head)
    visit household_daily_brief_plan_url(household_id: households(:home))

    click_on "In the ministry"
    within "dialog[open]" do
      assert_selector "h1", text: "Add a focus area"
      assert_field "Name", with: "In the ministry"
      assert_field "What it gives", with: "One way to prepare for, or share in, the ministry today."
      assert_field "Scriptures (optional)", with: "Matthew 28:19, 20; 2 Timothy 4:5"
      assert_text "Sent to the AI as you type it. Leave out names.", count: 2
      assert_accessible
      capture_screens("brief-focus-area-new")
      click_on "Add focus area"
    end

    assert_no_selector "dialog[open]"
    within("section[aria-labelledby=focus-areas]") do
      assert_selector "li", count: 6
      assert_selector "li:last-child h3", text: "In the ministry"
      assert_no_link "Add a focus area"
      assert_text "six focus areas, the most a plan can have"
    end

    click_on "Edit In the ministry"
    within "dialog[open]" do
      assert_selector "h1", text: "Edit focus area"
      fill_in "Scriptures (optional)", with: "Matthew 24:14"
      click_on "Save focus area"
    end
    assert_no_selector "dialog[open]"
    within("section[aria-labelledby=focus-areas] li:last-child") { assert_link "Matthew 24:14" }

    click_on "Edit In the ministry"
    within("dialog[open]") { click_on "Delete" }
    within "dialog[open]", text: "Delete “In the ministry”?" do
      assert_accessible
      capture_screens("brief-focus-area-delete")
      click_on "Delete focus area"
    end
    assert_text "Focus area deleted."
    within("section[aria-labelledby=focus-areas]") do
      assert_selector "li", count: 5
      assert_no_text "In the ministry"
      assert_link "Add a focus area"
    end

    uncheck "For the children"
    select "6:00 AM", from: "Ready by"
    click_on "Save plan"

    assert_text "Plan saved. Your next brief follows it."
    assert_no_checked_field "For the children"
    assert_checked_field "Evening questions"
    assert_select "Ready by", selected: "6:00 AM"
    assert_equal [ %w[ daily_text reading faith_example evening ], 360 ], [ plan.reload.sections, plan.ready_at_minutes ]
    capture_screens("brief-plan-saved", scroll_to: "#whats-sent")
  end

  # Today's row and "The brief chooses" are custom colours, and the week scrolls in its own box on a phone.
  test "both pages pass assert_accessible in light and dark, at desktop and phone width" do
    sign_in identities(:head)
    plan_url = household_daily_brief_plan_url(household_id: households(:home))
    start_url = new_household_daily_brief_plan_url(household_id: households(:home))

    [ [ 1400, 1400 ], [ 390, 844 ] ].each do |width, height|
      page.driver.browser.manage.window.resize_to(width, height)

      %w[ light dark ].each do |appearance|
        users(:head).update!(appearance:)
        DailyBrief::Plan.where(user: users(:head)).destroy_all

        visit start_url
        assert_selector "body[data-color-mode='#{appearance}'] h1", text: "Start your day with a daily brief"
        assert_accessible
        DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
        visit plan_url
        assert_selector "body[data-color-mode='#{appearance}'] h1", text: "Your plan"
        assert_accessible
      end
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
