require "test_helper"

class FamilyStudies::AiPanelComponentTest < ViewComponent::TestCase
  setup do
    @household = households(:home)
    @user = users(:head)
  end

  test "Start" do
    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user))

    assert_selector "turbo-frame#ai_panel"
    assert_selector "h2", text: "Plan it with AI"
    assert_text "It searches only jw.org and wol.jw.org"
    assert_button "Draft with AI"
    assert_no_selector "h2", text: "Before you use AI"
    assert_selector "[data-ai-panel-target=opened][hidden]", visible: :all
  end

  test "First use" do
    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, open: true))

    assert_no_button "Draft with AI"
    assert_selector "h2", text: "Before you use AI"
    assert_text "What's sent:"
    assert_text "Daily limit: your household can make 10 drafts a day."
    assert_selector "#ai_terms form[action='/ai_acceptance?return_to=%2F#{@household.id}%2Ffamily_studies%2Fnew%3Fai_panel%3Dopen']"
    assert_field "I understand how AI drafts work", type: :checkbox, checked: false
    assert_button "Turn on AI drafts"
    assert_button "Not now"
    assert_no_field "What should the study be about?"
  end

  test "Describe, with 8 of 10 drafts left today" do
    @user.accept_ai_terms(understood: "1")
    2.times { family_study_draft(household: @household) }

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, open: true))

    assert_selector "h2", text: "Draft with AI"
    assert_selector "form[action='/#{@household.id}/family_studies/drafts']"
    assert_field "What should the study be about?", type: :textarea
    assert_selector "textarea[name='family_study_draft[prompt]'][aria-required=true]"
    assert_button "A Bible chapter"
    assert_button "This week's meeting"
    assert_button "Something we're facing"
    assert_select "Length", options: [ "About 30 minutes", "About 45 minutes", "About 60 minutes" ], selected: "About 45 minutes"
    assert_field "Keep it easy for young children to follow", type: :checkbox
    assert_text "Leave out names and private family details."
    assert_button "Draft outline"
    assert_text "8 of 10 drafts left today for the The Head Family"
  end

  test "Describe with the draft's errors and text kept" do
    @user.accept_ai_terms(understood: "1")
    draft = FamilyStudy::Draft.new(prompt: "", length_minutes: 60).tap(&:validate)

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: draft, open: true))

    assert_text "can't be blank"
    assert_select "Length", selected: "About 60 minutes"
  end

  test "Limit reached" do
    @user.accept_ai_terms(understood: "1")
    @household.update!(time_zone: "Central Time (US & Canada)")
    10.times { family_study_draft(household: @household) }

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, open: true))

    assert_selector ".flash-warn, .Banner--warning", text: "You've used today's 10 drafts"
    assert_text "The The Head Family can draft again after midnight, Central Time. You can still plan this study yourself in the form."
    assert_selector "textarea[disabled]"
    assert_button "Draft outline", disabled: true
    assert_button "Close"
    assert_no_text "drafts left today"
  end

  test "Drafting" do
    draft = family_study_draft(household: @household)

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: draft))

    assert_selector "turbo-frame#ai_panel ##{ActionView::RecordIdentifier.dom_id(draft)}"
    assert_text "Drafting with AI"
    assert_no_button "Draft outline"
  end
end
