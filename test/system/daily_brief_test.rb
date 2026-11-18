require "application_system_test_case"

# Today's brief, from the plan alone (docs/design/daily-brief.md, The brief; frames brief-base.png without its Banner, and
# phone-brief.png). Nothing here calls an AI provider: the brief has no writing yet.
class DailyBriefSystemTest < ApplicationSystemTestCase
  setup do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
    travel_to(2.days.ago) { DailyBrief::Plan.start(users(:head), starter: "husband_and_father") }
    @brief = DailyBrief.for(users(:head))
  end

  test "open today's brief from the sidebar, with the Daily text link to wol.jw.org for today's date" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    within("aside") { click_on "Daily brief" }

    assert_selector "h1", text: "Daily brief"
    assert_selector "aside nav [aria-current=page]", text: "Daily brief"
    today = users(:head).today
    assert_text "#{today.strftime("%A, %B %-d")} · Only you see this."
    assert_link "Open today's text on wol.jw.org", href: "https://wol.jw.org/en/wol/dt/r1/lp-e/#{today.year}/#{today.month}/#{today.day}"
    assert_selector "h2", text: "From your plan"
    assert_link "1 Timothy 3:8-13"
    assert_selector "h2", text: "Today in Aglowy"
    assert @brief.reload.seen_at
    assert_accessible
    capture_screens("brief-today")
    capture_screens("brief-today-focus", scroll_to: "#daily-brief-focus")
  end

  test "before the first brief, Prepare today's brief makes it" do
    @brief.destroy!
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    assert_selector "h2", text: "Your first brief is ready tomorrow morning"
    assert_accessible
    capture_screens("brief-first")

    click_on "Prepare today's brief"

    assert_link "Open today's text on wol.jw.org"
  end

  test "paused, the page says why and Start it again goes back to the plan" do
    users(:head).daily_brief_plan.pause(reason: "unseen")
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    assert_selector "h2", text: "Your daily brief is paused"
    assert_text "You hadn't looked at seven briefs in a row."
    assert_accessible
    capture_screens("brief-paused")

    click_on "Start it again"

    assert_selector "h1", text: "Your plan"
    assert_text "Your daily brief is on again."
  end
end
