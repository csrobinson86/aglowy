require "application_system_test_case"

# Today's brief, from the plan alone or written by AI (docs/design/daily-brief.md, The brief; frames brief-today.png,
# brief-base.png and phone-brief.png), with Another angle, Write it with AI, Turn on AI drafts and Stop. The test queue
# adapter only enqueues a writing's job; write_brief runs it here with the AI stubbed, so nothing calls an AI provider.
class DailyBriefSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  THREAD = "Patience is letting Jehovah's timing be Jehovah's timing, instead of pushing for a faster, easier one of my own.".freeze

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
    assert_button "Another angle"
    assert_text "2 left today"
    assert_turbo_idle
    assert_accessible
    capture_screens("brief-written")
    capture_screens("brief-written-focus", scroll_to: "#daily-brief-focus")
  end

  test "link Reaching out to a goal, see it on the plan and on the brief with its next step, and complete it" do
    goal = users(:head).goals.create!(set_by: users(:head), title: "Qualify as a ministerial servant", target_on: Date.new(2027, 6, 30))
    goal.add_step(title: "Read 1 Timothy 3").tick(for: nil, by: users(:head))
    goal.add_step(title: "Ask an elder where I can help")
    goal.add_step(title: "Offer to help with the literature")
    sign_in identities(:head)
    visit household_daily_brief_plan_url(household_id: households(:home))

    find("a[aria-label='Edit Reaching out']").click
    within "dialog[open]" do
      select "Qualify as a ministerial servant", from: "Linked goal"
      click_on "Save focus area"
    end

    assert_no_selector "dialog[open]"
    within("section[aria-labelledby=focus-areas] li", text: "Reaching out") do
      assert_text "Linked to your goal"
      assert_link "Qualify as a ministerial servant", href: household_goal_path(household_id: households(:home), id: goal)
    end
    assert_accessible
    capture_screens("brief-plan-goal", scroll_to: "section[aria-labelledby=focus-areas]")

    within("aside") { click_on "Daily brief" }

    within("#daily-brief-focus") do
      assert_text "Your goal: Qualify as a ministerial servant · next step: Ask an elder where I can help"
    end
    assert_accessible
    capture_screens("brief-goal", scroll_to: "#daily-brief-focus")

    goal.complete(by: users(:head))
    visit household_daily_brief_url(household_id: households(:home))

    within("#daily-brief-focus") do
      assert_text "Reaching out"
      assert_no_text "Your goal"
    end
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

  test "ask for another angle, watch it being written, and see the new one" do
    written_writing
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    click_on "Another angle"

    assert_selector "h2", text: "Writing with AI"
    assert_text "Until then, here's the brief you have."
    assert_selector "li", text: "Searching jw.org and wol.jw.org"
    assert_button "Stop"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_accessible
    capture_screens("brief-writing")

    write_brief(thread: "Waiting on Jehovah is trusting that his timing is kinder than mine.")

    assert_text "Waiting on Jehovah is trusting that his timing is kinder than mine."
    assert_no_text THREAD
    assert_no_selector "h2", text: "Writing with AI"
    assert_text "1 left today"
    assert_accessible
  end

  test "at 3 used today the button is gone, and the page says No more today" do
    written_writing
    2.times { Ai::Use.create!(user: users(:head), purpose: "daily_brief") }
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    assert_text THREAD
    assert_no_button "Another angle"
    assert_text "No more today"
    assert_accessible
    capture_screens("brief-limit", scroll_to: "#daily-brief-faith")
  end

  test "a brief with no writing has Write it with AI, and Stop ends it with the parts from the plan" do
    users(:head).accept_ai_terms(understood: "1")
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))
    assert_selector "input[type=hidden][name=first][value=true]", visible: :all

    click_on "Write it with AI"

    assert_text "Until then, here are the parts from your plan."

    assert_selector "h2", text: "Writing with AI"
    assert_predicate @brief.writings.sole, :writing?

    click_on "Stop"

    assert_selector ".Banner", text: "Writing today's brief was stopped."
    assert_button "Try again"
    assert_predicate @brief.writings.sole, :stopped?
    assert_accessible
  end

  test "accept the AI terms from the brief, and today's writing starts" do
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))
    assert_no_button "Write it with AI"

    click_on "Turn on AI drafts"
    within("dialog") do
      assert_text "What's sent"
      check "I understand how AI drafts work"
      assert_accessible
      capture_screens("brief-ai-terms")
      click_on "Turn on AI drafts"
    end

    assert_selector "h2", text: "Writing with AI"
    assert users(:head).accepted_ai_terms?
    assert_predicate @brief.writings.sole, :writing?
  end

  test "switch to Evening and back, and Write a note about today opens a new note titled with the date" do
    written_writing
    travel_to Time.utc(2026, 11, 18, 1) # 7:00 PM in Hannah's zone
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    within("section[aria-labelledby=daily-brief-evening-note-heading]") { assert_text "Four questions to end the day." }

    click_on "Evening"

    assert_selector "h2", text: "Four questions to end the day"
    assert_selector "[aria-current=true]", text: "Evening"
    assert_text "Where did I push for my own timing today?"
    assert_text "Aglowy doesn't ask for your answers and saves nothing here."
    assert_selector "h2", text: "Today's brief"
    assert_no_selector "h2", text: "One thing in each role"
    assert_turbo_idle
    assert_accessible
    capture_screens("brief-evening")

    click_on "Morning"

    assert_selector "h2", text: "One thing in each role"
    assert_no_selector "h2", text: "Four questions to end the day"

    click_on "Evening"
    click_on "Write a note about today"

    assert_selector "h1", text: "New note"
    assert_field "Title", with: "Tuesday, November 17"
    assert_equal 0, users(:head).personal_notes.where(title: "Tuesday, November 17").count
    assert_accessible
  end

  test "before 6:00 PM the Evening part says when its questions open" do
    written_writing
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home), part: "evening")

    assert_text "They open here at 6:00 PM."
    assert_no_text "Where did I push for my own timing today?"
    assert_accessible
    capture_screens("brief-evening-closed")
  end

  test "from Home, Open today's brief lands on the brief" do
    written_writing
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    within(".daily-brief-home-card") do
      assert_selector "h2", text: "Your daily brief"
      assert_text "Only you see this"
      assert_text THREAD
      assert_text "Matthew 16:21-23"
      assert_text "Abraham and Moses"
    end
    assert @brief.reload.seen_at
    assert_turbo_idle
    assert_accessible
    capture_screens("brief-home")

    click_on "Open today's brief"

    assert_selector "h1", text: "Daily brief"
    assert_text "Today's thread"
  end

  # For the children, and sharing (docs/design/daily-brief.md; frames brief-today.png, brief-evening.png and
  # brief-family.png).
  test "share today's thought, see it on another member's Home, and stop sharing" do
    written_writing
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    within("section[aria-labelledby=daily-brief-children-heading]") do
      assert_text "Have you ever really wanted something right now, and had to wait?"
      assert_text "Shares today's thread, the reading and this box with The Head Family for today. Nothing else."
      click_on "Share with the family"
    end

    assert_text "Shared with The Head Family."
    within("section[aria-labelledby=daily-brief-children-heading]") do
      assert_selector ".Label", text: "Shared with The Head Family"
      assert_button "Stop sharing"
      assert_text "They see today's thread, the reading and this box until tomorrow."
    end
    assert_accessible
    capture_screens("brief-shared", scroll_to: "section[aria-labelledby=daily-brief-children-heading]")

    sign_in identities(:spouse)
    visit household_root_url(household_id: households(:home))

    within(".shared-thought") do
      assert_selector "h2", text: "Today's thought"
      assert_text "Shared by Hannah Head"
      assert_text THREAD
      assert_link "Matthew 16:21-23"
      assert_text "Let them practise waiting a turn, for a game or a snack, without asking to go first."
      assert_no_text "Peter wants a faster, kinder ending"
    end
    assert_turbo_idle
    assert_accessible
    capture_screens("brief-family")

    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))
    within("section[aria-labelledby=daily-brief-children-heading]") { click_on "Stop sharing" }

    assert_text "Stopped sharing with The Head Family."
    within("section[aria-labelledby=daily-brief-children-heading]") { assert_button "Share with the family" }

    sign_in identities(:spouse)
    visit household_root_url(household_id: households(:home))

    assert_selector "h1", text: "Home"
    assert_no_selector ".shared-thought"
  end

  test "Keep in Notes opens the brief as a note with the thread in it" do
    written = written_writing
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))

    click_on "Keep in Notes"

    assert_text "Kept in Notes."
    assert_field "Title", with: "Daily brief · Tuesday, November 17"
    within(".personal-note") do
      assert_text written.result["thread"]
      assert_text "One thing in each role"
      assert_link "Acts 10:29"
    end
    assert_turbo_idle
    assert_accessible
    capture_screens("brief-kept-note")
  end

  test "printed, the brief leaves out the sidebar, the side column and the buttons" do
    written = written_writing
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))
    assert_button "Print"
    assert_selector "aside", text: "Daily brief"

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")

    assert_no_selector "aside"
    assert_no_selector "h2", text: "Today in Aglowy"
    assert_no_button "Keep in Notes"
    assert_no_button "Print"
    assert_no_button "Another angle"
    assert_no_link "Your plan"
    assert_no_selector ".Subhead-actions"
    assert_selector "h1", text: "Daily brief"
    assert_text written.result["thread"]
    assert_selector "h2", text: "One thing in each role"

    # Paper is narrower than md, where the phone's top bar would otherwise show.
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 740, height: 1000, deviceScaleFactor: 1, mobile: false)
    assert_no_selector ".app-shell__top-bar"
    assert_no_button "Open menu"
    assert_selector "h2", text: "One thing in each role"
    # capture_screens sets the colour scheme, which clears print, so this one is saved as it is.
    page.save_screenshot(Rails.root.join("tmp/screenshots/ui/brief-print-paper-light.png")) if ENV["SCREENSHOTS"]
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  test "with a dark appearance the brief prints in light colours, and goes back to dark afterwards" do
    users(:head).update!(appearance: "dark")
    sign_in identities(:head)
    visit household_daily_brief_url(household_id: households(:home))
    assert_selector "body[data-color-mode=dark]"
    assert_button "Print"

    execute_script("window.dispatchEvent(new Event('beforeprint'))")
    assert_selector "body[data-color-mode=light]"

    execute_script("window.dispatchEvent(new Event('afterprint'))")
    assert_selector "body[data-color-mode=dark]"
  end

  private
    # Runs the queued writing's job with moderation stubbed and the saved reply (test/fixtures/files/ai/daily_brief.json)
    # given +thread+, through the real Chat#ask_within_purpose with the provider's connection stubbed.
    def write_brief(thread:)
      writing = DailyBrief::Writing.writing.sole
      ask_for_real = writing.chat.method(:ask_within_purpose)
      body = JSON.parse(file_fixture("ai/daily_brief.json").read.sub(THREAD, thread))
      ask = lambda do |text, stream:|
        stream.call(RubyLLM::Chunk.new(role: :assistant, content: "{"))
        response = Faraday::Response.new(Faraday::Env.from(status: 200, body: body))
        writing.chat.to_llm.provider.connection.stub(:post, ->(*, **) { response }) { ask_for_real.call(text) }
      end

      Ai::Moderation.stub(:flagged?, false) do
        writing.chat.stub(:ask_within_purpose, ask) do
          DailyBrief::Writing.stub(:find_by, writing) { perform_enqueued_jobs }
        end
      end
    end

    # The saved reply's fields and pages (test/fixtures/files/ai/daily_brief.json), as the checks keep them.
    def written_writing
      users(:head).accept_ai_terms(understood: "1")
      body = JSON.parse(file_fixture("ai/daily_brief.json").read)
      results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { it.slice("url", "title") }
      daily_brief_writing(@brief, status: "written", sources: results,
        result: JSON.parse(body["content"].filter_map { it["text"] }.join).except("off_topic"))
    end
end
