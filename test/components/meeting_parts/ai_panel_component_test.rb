require "test_helper"

class MeetingParts::AiPanelComponentTest < ViewComponent::TestCase
  RESULT = {
    "aim" => "Leave the person curious about what the Bible promises for the earth.",
    "opening" => "Mention something good in the neighbourhood, then ask what they think the future holds.",
    "points" => [ { "heading" => "A promise worth hearing", "scripture" => "Psalm 37:10, 11", "explain" => "Say in one sentence that it speaks of peace on the earth." },
                  { "heading" => "Let them talk", "explain" => "Ask what stood out to them, and listen without correcting." } ],
    "question" => "How will God bring that about?",
    "close" => "Thank them, and agree on a day to come back.",
    "study_point" => "Mark where in your opening you will apply the lesson."
  }.freeze
  SOURCES = [ { "url" => "https://wol.jw.org/en/wol/d/r1/lp-e/1102023301", "title" => "Love People brochure: lesson 1" },
              { "url" => "https://www.jw.org/en/bible-teachings/questions/future-of-earth/", "title" => "" } ].freeze

  setup do
    @household = households(:home)
    @user = users(:head)
    @part = meeting_parts(:head_conversation)
  end

  test "First use" do
    render_panel

    assert_selector "turbo-frame#ai_panel"
    assert_selector "h2", text: "Before you use AI"
    assert_text "What's sent: the part's kind, minutes, setting, topic and study point, and what you type."
    assert_text "15 requests a day"
    assert_selector "#ai_terms form[action='/ai_acceptance?not_now=false&return_to=%2F#{@household.id}%2Fmeeting_parts%2F#{@part.id}']"
    assert_button "Turn on AI drafts"
    assert_no_button "Not now"
    assert_no_field "Anything it should know? (optional)"
  end

  test "Start, with 15 of 15 left today and no choice of what would help yet" do
    @user.accept_ai_terms(understood: "1")

    render_panel

    assert_selector "h2", text: "Prepare with AI"
    assert_text "15 of 15 left today"
    assert_text "It aims at your 3 minutes."
    assert_selector "form[action='/#{@household.id}/meeting_parts/#{@part.id}/drafts'][method=post]"
    assert_field "Anything it should know? (optional)", type: :textarea
    assert_text "Only the part's details above and what you type here are sent. Never your preparation, names or anything else."
    assert_button "Draft outline"
    assert_no_text "What would help?"
    assert_no_selector ".Banner--error"
    # On a phone, "Prepare with AI" opens the panel in a full-screen dialog; from md up the panel sits beside the preparation.
    assert_selector "[data-ai-panel-target=start].d-md-none button", text: "Prepare with AI"
    assert_selector "[data-ai-panel-beside-value=true]"
    assert_selector "dialog#ai-panel-dialog.Overlay--full-whenNarrow", visible: :all
  end

  test "Drafting" do
    draft = meeting_part_draft(@part)

    render_panel(draft:)

    assert_selector "h2", text: "Drafting with AI"
    assert_selector "turbo-cable-stream-source", visible: :all
    assert_selector "ul#progress_meeting_part_draft_#{draft.id}", text: "Searching jw.org and wol.jw.org"
    assert_selector "form[action='/#{@household.id}/meeting_parts/#{@part.id}/drafts/#{draft.id}'] input[name=_method][value=delete]", visible: :all
    assert_button "Stop"
    assert_text "14 of 15 left today"
  end

  test "Outline" do
    draft = meeting_part_draft(@part, status: "drafted", result: RESULT, sources: SOURCES)

    render_panel(draft:)

    assert_selector "h3", text: "Outline"
    assert_text draft.spoken_length.to_s
    assert_text "Aim"
    assert_text "Leave the person curious about what the Bible promises for the earth."
    assert_text "Point 1 · A promise worth hearing"
    assert_selector "a.scripture-link", text: "Psalm 37:10, 11"
    assert_text "Point 2 · Let them talk"
    assert_text "Leave a question"
    assert_text "Your study point"
    assert_text "Pages it used"
    assert_link "Love People brochure: lesson 1", href: SOURCES.first["url"]
    assert_link "jw.org", href: SOURCES.last["url"]
    assert_selector ".Banner--warning", text: "AI can get things wrong. Check each point against its source."
    assert_selector "button[data-action='ai-draft#use']", text: "Use this outline"
    assert_selector "template[data-ai-draft-target=template]", visible: :all
    assert_selector "form[action='/#{@household.id}/meeting_parts/#{@part.id}/drafts/#{draft.id}'] input[name=_method][value=delete]", visible: :all
    assert_button "Discard"
    assert_selector "[data-ai-draft-target=added][hidden]", text: "Outline added", visible: :all
    assert_no_text "Write sample wording"
    assert_no_text "Ask for a change"
  end

  test "an outline for a talk with no question or study point leaves those out" do
    draft = meeting_part_draft(@part, status: "drafted", result: RESULT.merge("question" => "", "study_point" => nil))

    render_panel(draft:)

    assert_no_text "Leave a question"
    assert_no_text "Your study point"
    assert_text "No matching pages found on jw.org or wol.jw.org."
  end

  test "Limit reached" do
    @user.accept_ai_terms(understood: "1")
    15.times { Ai::Use.create!(user: @user, purpose: "meeting_part") }

    render_panel

    assert_selector ".Banner--warning", text: "You've used today's 15 requests"
    assert_text "You can ask again after midnight"
    assert_button "Draft outline", disabled: true
    assert_text "0 of 15 left today"
  end

  test "Off topic, and flagged" do
    %w[ off_topic flagged ].each do |status|
      draft = meeting_part_draft(@part, status: status)

      render_panel(draft:)

      assert_selector ".Banner", text: "This helper only prepares your meeting part."
      assert_button "Start again"
      assert_no_text "AI can get things wrong"
    end
  end

  test "the provider failing shows Start with a Banner" do
    @user.accept_ai_terms(understood: "1")
    draft = meeting_part_draft(@part, status: "failed", request: "The person is busy.")

    render_panel(draft:)

    assert_selector ".Banner--error", text: "Couldn't make a draft right now. Try again in a moment."
    assert_field "Anything it should know? (optional)", with: "The person is busy."
    assert_button "Draft outline"
  end

  test "AI text is escaped: a draft holding <script> renders as text" do
    draft = meeting_part_draft(@part, status: "drafted", result: RESULT.merge("aim" => "<script>alert('aim')</script>"),
                                      sources: [ { "url" => SOURCES.first["url"], "title" => "<script>alert('source')</script>" } ])

    render_panel(draft:)

    assert_no_selector "script", visible: :all
    assert_text "<script>alert('aim')</script>"
    assert_link "<script>alert('source')</script>"
    assert_includes page.find("template", visible: :all).native.inner_html, "&lt;script&gt;alert('aim')&lt;/script&gt;"
  end

  private
    def render_panel(draft: nil)
      render_inline(MeetingParts::AiPanelComponent.new(household: @household, meeting_part: @part, user: @user, draft: draft))
    end
end
