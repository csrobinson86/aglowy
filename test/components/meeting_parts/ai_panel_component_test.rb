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

  test "Start, with 15 of 15 left today, and What would help?" do
    @user.accept_ai_terms(understood: "1")

    render_panel

    assert_selector "h2", text: "Prepare with AI"
    assert_text "15 of 15 left today"
    assert_text "It aims at your 3 minutes."
    assert_selector "form[action='/#{@household.id}/meeting_parts/#{@part.id}/drafts'][method=post]"
    assert_field "Anything it should know? (optional)", type: :textarea
    assert_text "Only the part's details above and what you type here are sent. Never your preparation, names or anything else."
    assert_selector "fieldset legend", text: "What would help?"
    assert_field "An outline", type: :radio, checked: true
    assert_field "Sample wording", type: :radio, checked: false
    assert_selector "input[type=radio][value=wording][data-action='ai-panel#kindChosen'][data-ai-panel-label-param='Draft wording']"
    assert_button "Draft outline"
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
    assert_selector "form[action='/#{@household.id}/meeting_parts/#{@part.id}/drafts'] input[name='meeting_part_draft[kind]'][value=wording]", visible: :all
    assert_selector "form input[name='meeting_part_draft[revises_id]'][value='#{draft.id}']", visible: :all, count: 2
    assert_button "Write sample wording"
    assert_no_text "Back to the outline"
    assert_no_text "This runs about"
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
    assert_match %r{<template data-ai-draft-target="template">.*<strong>Aim:</strong> &lt;script&gt;alert\(&#39;aim&#39;\)&lt;/script&gt;}m, rendered_content
  end

  LINES = [ %w[ you Hello. ], %w[ other Hi. ], %w[ you How\ are\ you? ], %w[ other Fine. ], %w[ you Good. ], %w[ you Sixth\ line. ],
            %w[ other Seventh\ line. ], %w[ you Eighth\ line. ] ].map { |speaker, text| { "speaker" => speaker, "text" => text } }.freeze

  test "Wording for a demonstration: labels, a scripture to read, the first 6 lines and the rest in the details" do
    outline = meeting_part_draft(@part, status: "drafted", result: RESULT)
    lines = LINES.dup.tap { it[4] = it[4].merge("read" => "Psalm 37:10, 11") }
    draft = meeting_part_draft(@part, kind: "wording", status: "drafted", revises: outline, revised_result: RESULT, result: { "lines" => lines })

    render_panel(draft:)

    assert_selector "h3", text: "Sample conversation"
    assert_text "#{draft.spoken_length}, plus 1 scripture to read"
    assert_selector "ol.meeting-part-wording > li", count: 6
    assert_selector "ol.meeting-part-wording > li:first-child", text: "You Hello.", normalize_ws: true
    assert_selector "ol.meeting-part-wording > li:nth-child(2)", text: "Householder Hi.", normalize_ws: true
    assert_selector "ol.meeting-part-wording > li:nth-child(5)", text: /\(Read Psalm 37:10, 11\s*\)/ # the whitespace is inside the link icon's svg
    assert_selector "ol.meeting-part-wording > li:nth-child(5) a.scripture-link", text: "Psalm 37:10, 11"
    assert_selector "details summary", text: "Show all 8 lines"
    assert_selector "details ol > li", text: "Seventh line.", visible: :all
    assert_selector "details ol > li", count: 2, visible: :all
    assert_selector ".Banner--warning", text: "This is a sample to learn from. Put it in your own words, and check each point against its source."
    assert_selector "button[data-action='ai-draft#use']", text: "Use this wording"
    assert_link "Back to the outline", href: "/#{@household.id}/meeting_parts/#{@part.id}/drafts/#{outline.id}"
    assert_no_button "Write sample wording"
    assert_selector "[data-ai-draft-target=added][hidden]", text: "Wording added", visible: :all
    assert_text "Version 1 of the wording"
  end

  test "Wording for a talk: no labels, and no Show all with 6 lines or fewer" do
    part = meeting_parts(:spouse_talk)
    draft = meeting_part_draft(part, kind: "wording", status: "drafted", result: { "lines" => LINES.first(3).map { it.merge("speaker" => "you") } })

    render_inline(MeetingParts::AiPanelComponent.new(household: @household, meeting_part: part, user: users(:spouse), draft: draft))

    assert_selector "h3", text: "Sample talk"
    assert_selector "ol.meeting-part-wording > li", count: 3
    assert_no_selector ".meeting-part-wording .text-bold"
    assert_no_selector "details"
    assert_no_text "scripture to read"
    assert_no_text "Back to the outline"
  end

  test "Ask for a change: the chips, the box, Change it, what's sent, and Discard" do
    draft = meeting_part_draft(@part, status: "drafted", result: RESULT)

    render_panel(draft:)

    assert_selector "h3", text: "Ask for a change"
    form = "form[action='/#{@household.id}/meeting_parts/#{@part.id}/drafts'][method=post]"
    assert_selector "#{form} input[name='meeting_part_draft[kind]'][value=outline]", visible: :all
    [ "Shorter opening", "Simpler words", "A different scripture" ].each do
      assert_selector "#{form} button[type=button][data-action='ai-panel#fill'][data-ai-panel-text-param='#{it}']", text: it
    end
    assert_field "Your change", type: :text
    assert_selector "input[name='meeting_part_draft[request]'][data-ai-panel-target=prompt][maxlength='300']"
    assert_text "Sends the part's details, this draft and your change. Never your preparation."
    assert_button "Change it"
    assert_text "Version 1 of the outline"
    assert_no_link "See version 1"
    assert_button "Discard"
  end

  test "the version line: Version 2 links to version 1" do
    version1 = meeting_part_draft(@part, status: "drafted", result: RESULT)
    draft = meeting_part_draft(@part, status: "drafted", revises: version1, revised_result: RESULT, request: "Shorter opening", result: RESULT)

    render_panel(draft:)

    assert_text "Version 2 · See version 1"
    assert_link "See version 1", href: "/#{@household.id}/meeting_parts/#{@part.id}/drafts/#{version1.id}"
    assert_selector "form input[name='meeting_part_draft[revises_id]'][value='#{draft.id}']", visible: :all, count: 2
  end

  test "a refused change shows the draft it would change, with the error and the change kept" do
    @user.accept_ai_terms(understood: "1")
    shown = meeting_part_draft(@part, status: "drafted", result: RESULT)
    change = @part.draft(kind: "outline", request: "a" * 301, revises: shown, by: @user)

    render_panel(draft: change)

    assert_selector "h3", text: "Outline"
    assert_text "Leave the person curious about what the Bible promises for the earth."
    assert_field "Your change", with: "a" * 301
    assert_text "is too long"
  end

  test "Over the time: a draft more than 15% over says by how much, once" do
    draft = meeting_part_draft(@part, kind: "wording", status: "drafted", result: { "lines" => [ { "speaker" => "you", "text" => "word " * 455 } ] })

    render_panel(draft:)

    assert_equal 210, draft.spoken_length.seconds
    assert_selector "p", text: "This runs about 30 s over. Ask for a change to shorten it.", count: 1
    assert_selector "p svg.octicon-alert"
  end

  test "Start after a failed wording draft keeps Sample wording chosen, and a change to a draft that's gone shows why" do
    @user.accept_ai_terms(understood: "1")
    render_panel(draft: meeting_part_draft(@part, kind: "wording", status: "failed"))

    assert_field "Sample wording", type: :radio, checked: true
    assert_button "Draft wording"

    gone = meeting_part_draft(@part, status: "discarded", result: RESULT)
    render_panel(draft: @part.draft(kind: "outline", request: " ", revises: gone, by: @user))

    assert_selector ".Banner--error", text: "That draft can't be changed now."
    assert_button "Draft outline"
    assert_no_text "can't be blank"
  end

  private
    def render_panel(draft: nil)
      render_inline(MeetingParts::AiPanelComponent.new(household: @household, meeting_part: @part, user: @user, draft: draft))
    end
end
