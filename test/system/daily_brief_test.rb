require "application_system_test_case"

# Today's brief, from the plan alone (docs/design/daily-brief.md, The brief; frames brief-base.png without its Banner, and
# phone-brief.png). Nothing here calls an AI provider: the brief has no writing yet.
class DailyBriefSystemTest < ApplicationSystemTestCase
  # Tuesday 17 November 2026, 9:00 AM in Hannah's zone, so midnight can't fall between making the brief and opening it,
  # and the screenshots show the same weekday's plan every run.
  setup do
    travel_to Time.utc(2026, 11, 17, 15)
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
    assert_link "Open the Daily text on wol.jw.org", href: "https://wol.jw.org/en/wol/dt/r1/lp-e/#{today.year}/#{today.month}/#{today.day}"
    assert_selector "h2", text: "From your plan"
    assert_link "1 Timothy 3:8-13"
    assert_selector "h2", text: "Today in Aglowy"
    assert @brief.reload.seen_at
    assert_turbo_idle
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

    assert_link "Open the Daily text on wol.jw.org"
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

  test "a written brief shows the thread, every section and its sources" do
    written = written_writing
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    within("section[aria-labelledby=daily-brief-thread-heading]") do
      assert_text "Today's thread"
      assert_text written.result["thread"]
      assert_link "Matthew 16:21-23", href: "#daily-brief-reading"
    end
    assert_selector "h2", text: "Acts 10:28"
    assert_text "What it teaches me about Jehovah"
    assert_selector "h2", text: "Matthew 16:21-23 · Peter wants a faster, kinder ending"
    assert_text "Verse 22"
    assert_selector "h2", text: "Patience"
    assert_selector "h2", text: "He isn't slow. He waits for people."
    assert_selector "h2", text: "One thing in each role"
    assert_text "Ask about her day and listen to the end before offering a fix."
    assert_link "Ephesians 5:25"
    assert_selector "h2", text: "Abraham and Moses"
    assert_link "Hebrews 11:27"
    within("section[aria-labelledby=daily-brief-sources-heading]") do
      assert_link "Today's text and comment", href: "https://wol.jw.org/en/wol/dt/r1/lp-e/2026/11/17"
      assert_link "Imitate Their Faith: Abraham"
      assert_text "AI can get things wrong. Check each point against its source."
      assert_text "Written by AI"
      assert_link "What's sent"
    end
    assert_no_button "Another angle"
    assert_turbo_idle
    assert_accessible
    capture_screens("brief-written")
    capture_screens("brief-written-focus", scroll_to: "#daily-brief-focus")
  end

  test "a failed one shows the Banner and the parts from the plan" do
    users(:head).accept_ai_terms(understood: "1")
    daily_brief_writing(@brief, status: "failed")
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    assert_selector ".Banner", text: "Couldn't write today's brief with AI this time. Here are the parts from your plan."
    assert_link "Open the Daily text on wol.jw.org"
    assert_selector "h2", text: "From your plan"
    assert_no_text "Today's thread"
    assert_accessible
    capture_screens("brief-failed")
  end

  test "stopped, flagged and off topic each say so" do
    users(:head).accept_ai_terms(understood: "1")
    writing = daily_brief_writing(@brief)
    sign_in identities(:head)

    { "stopped" => "Writing today's brief was stopped.", "flagged" => "The AI couldn't write a brief from this plan.",
      "off_topic" => "The AI couldn't write a brief from this plan." }.each do |status, text|
      writing.update!(status:)
      visit household_daily_brief_url(household_id: households(:home))

      assert_selector ".Banner", text:
    end
  end

  test "being written shows the parts from the plan and no Banner" do
    users(:head).accept_ai_terms(understood: "1")
    daily_brief_writing(@brief)
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    assert_selector "h2", text: "From your plan"
    assert_no_selector ".Banner"
  end

  private
    # The saved reply's fields and pages (test/fixtures/files/ai/daily_brief.json), as the checks keep them.
    def written_writing
      users(:head).accept_ai_terms(understood: "1")
      body = JSON.parse(file_fixture("ai/daily_brief.json").read)
      results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { it.slice("url", "title") }
      daily_brief_writing(@brief, status: "written", sources: results,
        result: JSON.parse(body["content"].filter_map { it["text"] }.join).except("off_topic"))
    end
end
