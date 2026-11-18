require "application_system_test_case"

# Prepare with AI beside a part's preparation (docs/design/meeting-parts.md, Prepare with AI). The test queue adapter
# only enqueues the draft's job; write_draft runs it here with the AI stubbed, so nothing calls an AI provider.
class MeetingPartAiTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  EDITOR = "lexxy-editor[name='meeting_part[preparation]']"
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]
  REQUEST = "The person is busy and has a young family."

  setup do
    @part = meeting_parts(:head_conversation)
  end

  # Back to the suite's desktop window after a phone test (use_phone).
  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "accept the terms, draft an outline, Use this outline, see it in the editor with the Label, and save" do
    sign_in identities(:head)
    visit household_meeting_part_url(household_id: households(:home), id: @part)

    within("turbo-frame#ai_panel") do
      assert_selector "h2", text: "Before you use AI"
      check "I understand how AI drafts work"
      click_on "Turn on AI drafts"
      assert_text "15 of 15 left today"
      fill_in "Anything it should know? (optional)", with: REQUEST
    end
    assert_accessible
    capture_screens("part-ai-start", viewports: ScreenshotHelper::VIEWPORTS.slice(:desktop))

    within("turbo-frame#ai_panel") do
      click_on "Draft outline"
      assert_selector "h2", text: "Drafting with AI"
    end
    assert_selector "turbo-cable-stream-source[data-ai-panel-target='stream'][connected]", visible: :all
    assert_equal REQUEST, @part.drafts.sole.request

    write_draft(midway: -> { within("turbo-frame#ai_panel") { assert_selector "li", text: "Writing the outline…" } })

    within("turbo-frame#ai_panel") do
      assert_selector "h3", text: "Outline"
      assert_text "Leave the person curious about what the Bible promises for the earth."
      assert_link "Psalm 37:10, 11"
      assert_link "Love People brochure: lesson 1", href: "https://wol.jw.org/en/wol/d/r1/lp-e/1102023301"
      assert_text "14 of 15 left today"
    end
    assert_accessible
    capture_screens("part-ai-outline", viewports: ScreenshotHelper::VIEWPORTS.slice(:desktop))

    click_on "Use this outline"

    assert_selector EDITOR, text: "A promise worth hearing"
    assert_selector ".Label", text: "From an AI draft"
    assert_selector "turbo-frame#ai_panel h2", text: "Outline added"
    assert_accessible

    click_on "Save"

    assert_text "Part saved."
    assert_selector "#{EDITOR} .scripture-link", text: "Psalm 37:10, 11"
    assert_includes @part.reload.preparation.to_plain_text, "A promise worth hearing"
    assert_no_selector ".Label", text: "From an AI draft"
  end

  test "editing the preparation after Use this outline takes the Label away" do
    users(:head).accept_ai_terms(understood: "1")
    meeting_part_draft(@part, status: "drafted", result: { "aim" => "Leave the person curious.", "opening" => "Say hello.",
                                                           "points" => [ { "heading" => "A promise worth hearing", "explain" => "It speaks of peace." } ] })
    sign_in identities(:head)
    visit household_meeting_part_url(household_id: households(:home), id: @part)

    click_on "Use this outline"
    assert_selector ".Label", text: "From an AI draft"

    editable = find("#{EDITOR} [contenteditable='true']")
    editable.click
    editable.send_keys(END_OF_TEXT, " My own words.")

    assert_no_selector ".Label", text: "From an AI draft"
  end

  test "Use this outline goes after the preparation there, saved or not, and saves nothing" do
    users(:head).accept_ai_terms(understood: "1")
    @part.update!(preparation: "<p>My saved words.</p>")
    meeting_part_draft(@part, status: "drafted", result: { "aim" => "Leave the person curious.", "opening" => "Say hello.",
                                                           "points" => [ { "heading" => "A promise worth hearing", "explain" => "It speaks of peace." } ] })
    sign_in identities(:head)
    visit household_meeting_part_url(household_id: households(:home), id: @part)

    editable = find("#{EDITOR} [contenteditable='true']")
    editable.click
    editable.send_keys(END_OF_TEXT, " My unsaved words.")
    click_on "Use this outline"

    assert_selector EDITOR, text: "A promise worth hearing"
    assert_selector EDITOR, text: "My saved words. My unsaved words."
    assert_equal "My saved words.", @part.reload.preparation.to_plain_text.strip
  end

  test "on a phone Prepare with AI opens the panel full-screen, and Use this outline closes it" do
    users(:head).accept_ai_terms(understood: "1")
    use_phone
    sign_in identities(:head)
    visit household_meeting_part_url(household_id: households(:home), id: @part)

    assert_no_selector "dialog[open]"
    click_on "Prepare with AI"
    wait_for_dialog
    within("dialog[open]") do
      assert_field "Anything it should know? (optional)"
      fill_in "Anything it should know? (optional)", with: REQUEST
    end
    assert_accessible
    capture_screens("part-ai-start", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
    use_phone # capture_screens leaves the desktop window, which puts the panel back beside the preparation

    within("dialog[open]") do
      click_on "Draft outline"
      assert_selector "h2", text: "Drafting with AI"
    end
    assert_selector "turbo-cable-stream-source[data-ai-panel-target='stream'][connected]", visible: :all
    write_draft

    within("dialog[open]") { assert_selector "h3", text: "Outline" }
    assert_accessible
    capture_screens("part-ai-outline", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
    use_phone # capture_screens leaves the desktop window, which puts the panel back beside the preparation

    within("dialog[open]") { click_on "Use this outline" }

    assert_no_selector "dialog[open]"
    assert_selector EDITOR, text: "A promise worth hearing"
    assert_selector ".Label", text: "From an AI draft"
  end

  test "a child sees no Prepare with AI" do
    sign_in identities(:eli)
    visit household_meeting_part_url(household_id: households(:home), id: meeting_parts(:eli_conversation))

    assert_selector "h1", text: "Starting a Conversation"
    assert_no_selector "turbo-frame#ai_panel"
    assert_no_text "Prepare with AI"
  end

  private
    # The phone frame's size (390 × 844), with touch, so Primer's 44px touch targets apply.
    def use_phone
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
    end

    # Runs the draft's job here, with moderation passing and Chat#ask_within_purpose standing in for the provider: it
    # streams the saved reply's text (test/fixtures/files/ai/meeting_part_outline.json), calls +midway+ after the first
    # chunk, then answers with the saved reply as the provider's HTTP response would arrive. No test calls a provider.
    def write_draft(midway: -> { })
      draft = MeetingPart::Draft.sole
      ask_for_real = draft.chat.method(:ask_within_purpose)
      body = JSON.parse(file_fixture("ai/meeting_part_outline.json").read)
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
          MeetingPart::Draft.stub(:find_by, draft) { perform_enqueued_jobs }
        end
      end
    end
end
