require "application_system_test_case"

# The AI panel beside the Schedule form (docs/design/family-studies.md, AI helper). The test queue adapter only
# enqueues the draft's job; write_draft runs it here with the AI stubbed, so nothing calls an AI provider.
class FamilyStudyAiTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  # The three pages the saved reply's search returned (test/fixtures/files/ai/family_study_draft.json).
  SOURCES = %w[ https://www.jw.org/en/bible-teachings/family/family-worship/ https://wol.jw.org/en/wol/d/r1/lp-e/1200275025
                https://www.jw.org/en/bible-teachings/questions/how-to-pray/ ].freeze
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]

  # Back to the suite's desktop window after a phone test (use_phone).
  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "a head turns on AI drafts, describes a study and sees Drafting with AI" do
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))

    within("turbo-frame#ai_panel") do
      assert_selector "h2", text: "Plan it with AI"
      click_on "Draft with AI"
      assert_selector "h2", text: "Before you use AI"
    end
    assert_accessible
    capture_screens("ai-terms", scroll_to: "[data-ai-panel-target=opened]")

    within("turbo-frame#ai_panel") do
      check "I understand how AI drafts work"
      click_on "Turn on AI drafts"
      assert_field "What should the study be about?"
      click_on "Something we're facing"
      assert_field "What should the study be about?", with: /\ASomething our family is facing: /
      fill_in "What should the study be about?", with: "Trusting Jehovah when we feel anxious. Simple enough for younger children to join in."
      check "Keep it easy for young children to follow"
      assert_text "10 of 10 drafts left today"
    end
    assert_accessible
    capture_screens("ai-describe", scroll_to: "[data-ai-panel-target=opened]")

    within("turbo-frame#ai_panel") { click_on "Draft outline" }

    assert_selector "turbo-frame#ai_panel", text: "Drafting with AI"
    assert_equal "Trusting Jehovah when we feel anxious. Simple enough for younger children to join in.", households(:home).family_study_drafts.sole.prompt
    assert_predicate users(:head), :accepted_ai_terms?
  end

  test "Not now and Cancel go back to the start" do
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))

    within("turbo-frame#ai_panel") do
      click_on "Draft with AI"
      click_on "Not now"
      assert_button "Draft with AI"
      assert_no_selector "h2", text: "Before you use AI"
    end

    users(:head).accept_ai_terms(understood: "1")
    visit new_household_family_study_url(household_id: households(:home))

    within("turbo-frame#ai_panel") do
      click_on "Draft with AI"
      click_on "Cancel"
      assert_button "Draft with AI"
      assert_no_field "What should the study be about?"
    end
  end

  test "with 10 used: Limit reached, and the form still schedules a study" do
    users(:head).accept_ai_terms(understood: "1")
    10.times { family_study_draft(household: households(:home)) }
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))

    within("turbo-frame#ai_panel") do
      click_on "Draft with AI"
      assert_text "You've used today's 10 drafts"
      assert_button "Draft outline", disabled: true
    end
    assert_accessible
    capture_screens("ai-limit", scroll_to: "[data-ai-panel-target=opened]")

    date = 7.days.from_now.to_date
    fill_in "What will you study?", with: "Proverbs 3"
    fill_in "Date", with: date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    click_on "Schedule study"

    assert_text "Your family study is scheduled."
    assert_selector ".Box-row", text: "Proverbs 3"
  end

  test "on a phone the panel stacks under the form" do
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))
    emulate_viewport(390, 844, phone: true)

    assert_selector "turbo-frame#ai_panel h2", text: "Plan it with AI"
    assert_operator evaluate_script("document.querySelector('[data-ai-panel-target=start]').getBoundingClientRect().top"), :>,
      evaluate_script("document.querySelector('#schedule-links').getBoundingClientRect().top")
  ensure
    cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "on a phone the dialog opens, drafts and shows the footer" do
    start_draft_on_phone("Trusting Jehovah when we feel anxious")
    assert_selector "[data-ai-panel-target=start]", text: "Plan it with AI"

    write_draft("family_study_draft")

    within("dialog[open]") do
      assert_selector "h2", text: "AI draft"
      assert_selector ".Label", text: "Not saved"
      assert_selector "h3", text: "Talking to Jehovah as a family"
      within(".Overlay-footer") do
        assert_text "AI can get things wrong. Check each point against its source."
        assert_button "Use this draft"
        assert_button "Try again"
        assert_button "Discard"
      end
    end
    # Layout boxes, since the dialog scales in as it opens.
    use, again, discard, footer = [ "Use this draft", "Try again", "Discard" ].map { find_button(it) }.push(find("dialog[open] .Overlay-footer"))
      .map { it.evaluate_script("[ this.offsetTop, this.offsetLeft, this.offsetWidth ]") }
    assert_operator use[2], :>, footer[2] * 0.8
    assert_equal again[0], discard[0]
    assert_operator again[0], :>, use[0]
    assert_equal again[2], discard[2]
    assert_touch_targets
    assert_accessible
    capture_screens("phone-ai-draft", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "on a phone Use this draft closes the dialog and fills the form" do
    start_draft_on_phone("Talking to Jehovah together")
    write_draft("family_study_draft")

    within("dialog[open] .Overlay-footer") { click_on "Use this draft" }

    assert_no_selector "dialog[open]"
    assert_field "What will you study?", with: "Talking to Jehovah as a family"
    assert_selector "lexxy-editor", text: "Jehovah listens to each of us"
    assert_selector "#schedule-links li", count: 3
    assert_equal "Topic", evaluate_script("document.activeElement.textContent").strip
    assert evaluate_script("document.activeElement.getBoundingClientRect().top >= 0 && document.activeElement.getBoundingClientRect().bottom <= innerHeight")
    assert_button "Draft with AI"
  end

  test "on a phone Escape closes the dialog and returns focus to Draft with AI" do
    start_draft_on_phone("Talking to Jehovah together")
    write_draft("family_study_draft")
    assert_selector "dialog[open] h3", text: "Talking to Jehovah as a family"

    page.send_keys(:escape)

    assert_no_selector "dialog[open]"
    assert_no_text "Talking to Jehovah as a family"
    assert_equal "Draft with AI", evaluate_script("document.activeElement.textContent").strip
  end

  test "on a phone a draft that comes after Escape waits for Draft with AI" do
    start_draft_on_phone("Talking to Jehovah together")
    page.send_keys(:escape)
    assert_no_selector "dialog[open]"

    write_draft("family_study_draft")

    assert_selector "[data-ai-panel-target=opened] h3", text: "Talking to Jehovah as a family", visible: :hidden
    assert_no_selector "dialog[open]"

    click_on "Draft with AI"
    within("dialog[open]") { assert_selector "h3", text: "Talking to Jehovah as a family" }
  end

  test "on a phone each state shows in the dialog, with 44px touch targets" do
    use_phone
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home))
    assert_operator find_button("Draft with AI").evaluate_script("this.offsetHeight"), :>=, 44

    click_on "Draft with AI"
    within("dialog[open]") do
      assert_selector "h2", text: "Before you use AI"
      check "I understand how AI drafts work"
      click_on "Turn on AI drafts"
    end
    within("dialog[open]") do
      assert_selector "h2", text: "Draft with AI"
      assert_field "What should the study be about?"
    end
    assert_touch_targets

    within("dialog[open]") { click_on "Cancel" }
    assert_no_selector "dialog[open]"
    assert_equal "Draft with AI", evaluate_script("document.activeElement.textContent").strip
  end

  test "widening with the dialog open shows the panel beside the form" do
    start_draft_on_phone("Talking to Jehovah together")
    write_draft("family_study_draft")
    assert_selector "dialog[open] h3", text: "Talking to Jehovah as a family"

    cdp("Emulation.clearDeviceMetricsOverride")

    assert_no_selector "dialog[open]"
    within("turbo-frame#ai_panel .Box") do
      assert_selector "h2", text: "AI draft"
      assert_selector "h3", text: "Talking to Jehovah as a family"
      assert_button "Use this draft"
    end
    assert_no_button "Draft with AI"
  end

  test "progress lines show, then the checked draft replaces them with its links" do
    start_draft("Trusting Jehovah when we feel anxious")

    write_draft("family_study_draft", midway: lambda {
      within("turbo-frame#ai_panel") do
        assert_selector "li", text: "Searched jw.org and wol.jw.org"
        assert_selector "li", text: "Writing the outline…"
        assert_no_text "Talking to Jehovah"
      end
      assert_accessible
      capture_screens("ai-searching", scroll_to: "[data-ai-panel-target=opened]")
    })

    within("turbo-frame#ai_panel") do
      assert_selector "h2", text: "AI draft"
      assert_selector "h3", text: "Talking to Jehovah as a family"
      assert_link "Philippians 4:6, 7"
      assert_link "Family Worship", href: "https://www.jw.org/en/bible-teachings/family/family-worship/"
      assert_link "Praying Together as a Family", href: "https://wol.jw.org/en/wol/d/r1/lp-e/1200275025"
      assert_no_selector "li", text: "Writing the outline"
    end
    assert_predicate households(:home).family_study_drafts.sole, :drafted?
    assert_accessible
    capture_screens("ai-draft", scroll_to: "[data-ai-panel-target=opened]")
  end

  test "an off-topic reply shows the refusal" do
    start_draft("What's a good recipe for dinner tonight?")

    write_draft("off_topic")

    within("turbo-frame#ai_panel") do
      assert_text "You asked: “What's a good recipe for dinner tonight?”"
      assert_text "This helper only plans family studies"
      assert_button "Describe a study"
    end
    assert_accessible
    capture_screens("ai-refused", scroll_to: "[data-ai-panel-target=opened]")

    within("turbo-frame#ai_panel") { click_on "Describe a study" }
    assert_field "What should the study be about?", with: "What's a good recipe for dinner tonight?"
  end

  test "a result that's in before the panel listens still replaces Drafting" do
    users(:head).accept_ai_terms(understood: "1")
    sign_in identities(:head)
    visit new_household_family_study_url(household_id: households(:home), ai_panel: "open")
    fill_in "What should the study be about?", with: "Something that moderation flags"

    # The job runs inside the request, so its result is broadcast before the page has subscribed.
    Ai::Moderation.stub(:flagged?, true) do
      FamilyStudy::WriteDraftJob.stub(:perform_later, ->(id) { FamilyStudy::WriteDraftJob.perform_now(id).then { true } }) do
        within("turbo-frame#ai_panel") { click_on "Draft outline" }
        # Describe goes once the response, rendered after the job, is in.
        assert_no_field "What should the study be about?"
      end
    end

    within("turbo-frame#ai_panel") do
      assert_text "This helper only plans family studies"
      assert_no_text "Drafting with AI"
    end
    assert_predicate households(:home).family_study_drafts.sole, :flagged?
  end

  test "Stop during drafting returns to Describe" do
    start_draft("Trusting Jehovah when we feel anxious")

    within("turbo-frame#ai_panel") { click_on "Stop" }

    within("turbo-frame#ai_panel") do
      assert_field "What should the study be about?", with: "Trusting Jehovah when we feel anxious"
      assert_button "Draft outline"
      assert_text "9 of 10 drafts left today"
    end
    # The draft's stream; the shell's own stream for the person's notifications stays.
    assert_no_selector "turbo-cable-stream-source[data-ai-panel-target='stream']", visible: :all
    assert_predicate households(:home).family_study_drafts.sole, :stopped?
  end

  test "Use this draft fills Topic, Notes and three Resources, and Schedule study saves them" do
    start_draft("Talking to Jehovah together")
    write_draft("family_study_draft")

    within("turbo-frame#ai_panel") { click_on "Use this draft" }

    within("turbo-frame#ai_panel") do
      assert_selector "h2", text: "Draft added"
      assert_text "The topic, notes and 3 links from jw.org and wol.jw.org are now in the form."
      assert_button "Draft again"
      assert_no_button "Use this draft"
    end
    assert_field "What will you study?", with: "Talking to Jehovah as a family"
    assert_selector "lexxy-editor", text: "Jehovah listens to each of us"
    assert_selector "lexxy-editor", text: "Read Philippians 4:6, 7."
    assert_selector ".Label", text: "From an AI draft"
    assert_equal SOURCES, all("#schedule-links input[name='family_study_scheduling[link_urls][]']", visible: :hidden).map(&:value)
    assert_accessible
    capture_screens("ai-draft-added")
    capture_screens("ai-draft-added-notes", scroll_to: "[data-ai-draft-target=label]")
    # On a phone the open panel, now showing Draft added, is a full-screen dialog.
    capture_screens("ai-draft-added-panel", scroll_to: "[data-ai-draft-target=added]", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))

    fill_in "Date", with: 7.days.from_now.to_date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    click_on "Schedule study"

    assert_text "Your family study is scheduled."
    session = households(:home).family_studies.order(:created_at).last.sessions.sole
    assert_equal "Talking to Jehovah as a family", session.topic
    assert_equal %w[ 50:4:6-7 19:65:2 60:5:7 40:6:9 ].map { Bible::Reference.find(it) }, session.notes.body.attachables
    assert_equal SOURCES, session.resources.map(&:url)
    assert session.resources.all?(&:link?)
  end

  test "with a Topic already typed, Keep mine keeps it" do
    start_draft("Talking to Jehovah together")
    write_draft("family_study_draft")
    fill_in "What will you study?", with: "Praying as a family"

    within("turbo-frame#ai_panel") { click_on "Use this draft" }
    within("dialog", text: "Replace the topic?") do
      assert_text "Praying as a family"
      assert_text "Talking to Jehovah as a family"
      click_on "Keep mine"
    end

    assert_no_selector "dialog[open]"
    assert_field "What will you study?", with: "Praying as a family"
    assert_selector "turbo-frame#ai_panel h2", text: "Draft added"
    assert_selector "lexxy-editor", text: "Jehovah listens to each of us"
    assert_selector "#schedule-links li", count: 3
  end

  test "Replace takes the draft's title, and notes already written stay above the draft's" do
    start_draft("Talking to Jehovah together")
    write_draft("family_study_draft")
    fill_in "What will you study?", with: "Praying as a family"
    write_notes "Start with a song."

    within("turbo-frame#ai_panel") { click_on "Use this draft" }
    within("dialog", text: "Replace the topic?") { click_on "Replace" }

    assert_field "What will you study?", with: "Talking to Jehovah as a family"
    assert_selector "lexxy-editor", text: /Start with a song\..*Jehovah listens to each of us/m
  end

  test "a page already in Resources isn't listed twice" do
    start_draft("Talking to Jehovah together")
    write_draft("family_study_draft")
    within("turbo-frame#ai_panel") { click_on "Use this draft" }
    assert_selector "#schedule-links li", count: 3

    fill_in "Add a link", with: SOURCES.first
    click_on "Add link"

    assert_field "Add a link", with: ""
    assert_selector "#schedule-links li", count: 3
  end

  test "editing Notes removes the From an AI draft label" do
    start_draft("Talking to Jehovah together")
    write_draft("family_study_draft")
    within("turbo-frame#ai_panel") { click_on "Use this draft" }
    assert_selector ".Label", text: "From an AI draft"

    write_notes " Sing song 44."

    assert_no_selector ".Label", text: "From an AI draft"
    assert_selector "lexxy-editor", text: "Sing song 44."
  end

  test "Draft again on Draft added returns to Describe" do
    start_draft("Talking to Jehovah together")
    write_draft("family_study_draft")
    within("turbo-frame#ai_panel") { click_on "Use this draft" }

    within("turbo-frame#ai_panel") { click_on "Draft again" }

    within("turbo-frame#ai_panel") do
      assert_field "What should the study be about?", with: "Talking to Jehovah together"
      assert_button "Draft outline"
    end
    assert_field "What will you study?", with: "Talking to Jehovah as a family"
  end

  test "Discard instead: the form is unchanged" do
    start_draft("Talking to Jehovah together")
    write_draft("family_study_draft")
    fill_in "What will you study?", with: "Praying as a family"

    within("turbo-frame#ai_panel") { click_on "Discard" }

    assert_field "What should the study be about?", with: "Talking to Jehovah together"
    assert_field "What will you study?", with: "Praying as a family"
    assert_selector "lexxy-editor.lexxy-editor--empty"
    assert_no_selector "#schedule-links li"
    assert_text "No resources yet."
    assert_no_selector ".Label", text: "From an AI draft"
    assert_predicate households(:home).family_study_drafts.sole, :discarded?
  end

  test "a child sees no panel" do
    sign_in identities(:eli)
    visit new_household_family_study_url(household_id: households(:home))

    assert_text "You can't do that in this household."
    assert_no_selector "turbo-frame#ai_panel"
    assert_no_text "Plan it with AI"
  end

  private
    # The phone frame's size (390 × 844), with touch, so Primer's 44px touch targets apply.
    def use_phone
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
    end

    # On a phone, "Draft with AI" opens the panel as a full-screen dialog; the head describes a study in it.
    def start_draft_on_phone(prompt)
      users(:head).accept_ai_terms(understood: "1")
      use_phone
      sign_in identities(:head)
      visit new_household_family_study_url(household_id: households(:home))

      click_on "Draft with AI"
      within("dialog[open]") do
        fill_in "What should the study be about?", with: prompt
        click_on "Draft outline"
        assert_selector "h2", text: "Drafting with AI"
      end
      assert_selector "turbo-cable-stream-source[data-ai-panel-target='stream'][connected]", visible: :all
    end

    # Every button and select in the open dialog is at least 44px tall, and its close button 44px wide. A link-styled
    # button inside a line of text ("Change") is an inline target, which the size rule leaves out. Layout sizes, since
    # the dialog scales in as it opens.
    def assert_touch_targets
      sizes = evaluate_script(<<~JS)
        [ ...document.querySelectorAll("dialog[open] :is(button, select):not(.Link)") ].filter(target => target.checkVisibility())
          .map(target => [ target.textContent.trim() || target.getAttribute("aria-label"), target.offsetHeight, target.offsetWidth ])
      JS
      assert_not_empty sizes
      sizes.each do |name, height, _|
        assert_operator height, :>=, 44, "#{name} is #{height}px tall"
      end
      _, _, close_width = sizes.find { |name, *| name == "Close" }
      assert_operator close_width, :>=, 44
    end

    # A head with AI drafts turned on describes a study, and waits until the panel listens on the draft's stream.
    def start_draft(prompt)
      users(:head).accept_ai_terms(understood: "1")
      sign_in identities(:head)
      visit new_household_family_study_url(household_id: households(:home), ai_panel: "open")

      within("turbo-frame#ai_panel") do
        fill_in "What should the study be about?", with: prompt
        click_on "Draft outline"
        assert_selector "h2", text: "Drafting with AI"
      end
      assert_selector "turbo-cable-stream-source[data-ai-panel-target='stream'][connected]", visible: :all
    end

    # Types into the Notes editor the way a person does: focus the editable area, then type at its end.
    def write_notes(text)
      editor = find("lexxy-editor [contenteditable='true']")
      editor.click
      editor.send_keys(END_OF_TEXT, text)
    end

    # Runs the draft's job here, with moderation passing and Chat#ask_within_purpose standing in for the provider:
    # it streams the saved reply's text (test/fixtures/files/ai/), calls +midway+ after the first chunk, then
    # answers with the saved reply as the provider's HTTP response would arrive. No test calls a provider.
    def write_draft(name, midway: -> { })
      draft = FamilyStudy::Draft.sole
      ask_for_real = draft.chat.method(:ask_within_purpose)
      body = JSON.parse(file_fixture("ai/#{name}.json").read)
      ask = lambda do |text, stream:|
        body["content"].filter_map { it["text"] }.each_with_index do |chunk, index|
          stream.call(RubyLLM::Chunk.new(role: :assistant, content: chunk))
          midway.call if index.zero?
        end
        response = Faraday::Response.new(Faraday::Env.from(status: 200, body: body))
        draft.chat.to_llm.provider.connection.stub(:post, ->(*, **) { response }) { ask_for_real.call(text) }
      end

      Ai::Moderation.stub(:flagged?, false) do
        draft.chat.stub(:ask_within_purpose, ask) do
          FamilyStudy::Draft.stub(:find, draft) { perform_enqueued_jobs }
        end
      end
    end
end
