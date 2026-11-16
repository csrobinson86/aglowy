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
    assert_no_selector "[data-ai-panel-target=opened]"
    assert_selector "[data-ai-panel-target=opened][hidden]", visible: :all
    # Below md the open panel is a full-screen dialog; it scales in only when the person opens it.
    assert_selector "dialog#ai-panel-dialog.Overlay--full-whenNarrow:not(.ai-panel-dialog--open)", visible: :all
    assert_no_selector "#ai-panel-dialog .Overlay-footer", visible: :all
  end

  test "First use" do
    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, open: true))

    # From md up the Start box gives way to the open panel; below md it stays under the form.
    assert_selector "[data-ai-panel-target=start].d-md-none"
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
    @user.accept_ai_terms(understood: "1")
    draft = family_study_draft(household: @household, prompt: "Trusting Jehovah when we feel anxious, even at school", length_minutes: 45, young_children: true)

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: draft, open: true))

    assert_selector "turbo-frame#ai_panel h2", text: "Drafting with AI"
    assert_selector "turbo-cable-stream-source[channel='Turbo::StreamsChannel'][signed-stream-name='#{Turbo::StreamsChannel.signed_stream_name(draft)}']", visible: :all
    assert_text "From “Trusting Jehovah when we feel…” · about 45 minutes · young children"
    assert_selector "##{dom_id(draft, :progress)}[aria-live=polite] li", count: 3
    assert_selector "##{dom_id(draft, :progress)} li", text: "Searching jw.org and wol.jw.org…"
    assert_selector "##{dom_id(draft, :progress)} li", text: "Writing the outline"
    assert_selector "##{dom_id(draft, :progress)} li", text: "Checking scriptures, links and wording"
    assert_selector "##{dom_id(draft)}[aria-busy=true]", text: "The draft appears here once its scriptures, links and wording have been checked."
    assert_selector "form[action='/#{@household.id}/family_studies/drafts/#{draft.id}'] input[name=_method][value=delete]", visible: :all
    assert_button "Stop"
    assert_no_button "Draft outline"
  end

  test "Draft with sources" do
    draft = drafted(sources: [ { url: "https://www.jw.org/en/bible-teachings/family/family-worship/", title: "Family Worship" },
                               { url: "https://wol.jw.org/en/wol/d/r1/lp-e/1200275025", title: "Praying Together as a Family" } ])

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: draft, open: true))

    assert_selector "h2", text: "AI draft"
    assert_selector ".Label", text: "Not saved"
    assert_no_selector "turbo-cable-stream-source", visible: :all
    assert_text "From “Prayer as a family” · about 30 minutes"
    assert_button "Change"
    assert_selector "h3", text: "Talking to Jehovah as a family"
    assert_selector "a.scripture-link[href='#{Bible::Reference.parse("Philippians 4:6, 7").jw_url}'][target=_blank][rel=noopener]", text: "Philippians 4:6, 7"
    assert_selector "a.scripture-link", text: "Psalm 65:2"
    assert_text "Ask: Why does it matter that Jehovah hears even short prayers?"
    assert_selector "ol li", count: 2
    assert_text "Choose one thing to thank Jehovah for each day this week."
    assert_text "Found on jw.org and wol.jw.org"
    assert_link "Family Worship", href: "https://www.jw.org/en/bible-teachings/family/family-worship/"
    assert_selector "li", text: "Praying Together as a Family · wol.jw.org"
    assert_text "Titles and links only: open each page to read it"
    assert_no_text "No matching pages found"
    assert_selector ".Banner--warning", text: "AI can get things wrong. Check each point against its source before your study."
    assert_selector "dialog#ai-panel-dialog.ai-panel-dialog--open h2", text: "AI draft", visible: :all
    assert_selector "#ai-panel-dialog [data-ai-panel-target=dialogFooter]", visible: :all
    assert_selector "[data-ai-panel-target=footerHome] > [data-ai-panel-target=footer][data-ai-draft-target=review]",
      text: "AI can get things wrong. Check each point against its source.", visible: :all
    assert_selector "button[data-action='ai-draft#use']:not([disabled])", text: "Use this draft"
    assert_selector "template[data-ai-draft-target=template]", visible: :all
    assert_selector "dialog#ai-draft-topic", text: "Replace the topic?", visible: :all
    assert_selector "a[data-ai-draft-target=source]", count: 2
    assert_selector "[data-ai-draft-target=added][hidden]", text: "The topic, notes and 2 links from jw.org and wol.jw.org are now in the form.", visible: :all
    assert_button "Draft again", visible: :all
    assert_selector "form[action='/#{@household.id}/family_studies/drafts'] input[name='family_study_draft[prompt]'][value='Prayer as a family']", visible: :all
    assert_button "Try again"
    assert_selector "form[action='/#{@household.id}/family_studies/drafts/#{draft.id}'] input[name=_method][value=delete]", visible: :all
    assert_button "Discard"
  end

  test "Draft with none" do
    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: drafted(sources: []), open: true))

    assert_text "No matching pages found on jw.org or wol.jw.org."
    assert_no_text "Titles and links only"
    assert_selector "[data-ai-draft-target=added]", text: "The topic and notes are now in the form. Change anything you like before you schedule.", visible: :all
    assert_selector "a.scripture-link", text: "Philippians 4:6, 7"
    assert_button "Try again"
  end

  test "Off topic" do
    %w[ off_topic flagged ].each do |status|
      draft = family_study_draft(household: @household, prompt: "What's a good recipe for dinner tonight?", status: status)

      render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: draft, open: true))

      assert_selector "h2", text: "Draft with AI"
      assert_text "You asked: “What's a good recipe for dinner tonight?”"
      assert_selector ".Banner", text: "This helper only plans family studies"
      assert_text "Describe a topic, a Bible chapter or something your family is facing"
      assert_selector "form[action='/#{@household.id}/family_studies/drafts/#{draft.id}'] input[name=_method][value=delete]", visible: :all
      assert_button "Describe a study"
      assert_button "Close"
      assert_no_text "AI can get things wrong"
    end
  end

  test "Failed" do
    @user.accept_ai_terms(understood: "1")
    draft = family_study_draft(household: @household, prompt: "Prayer as a family", length_minutes: 60, status: "failed")

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: draft, open: true))

    assert_selector ".Banner--error", text: "Couldn't make a draft right now. Try again in a moment."
    assert_field "What should the study be about?", with: "Prayer as a family"
    assert_select "Length", selected: "About 60 minutes"
    assert_selector "form[action='/#{@household.id}/family_studies/drafts'][method=post]"
    assert_no_selector "input[name=_method]", visible: :all
    assert_button "Draft outline"
    assert_no_selector "turbo-cable-stream-source", visible: :all
  end

  test "a <script> in a question renders as text" do
    draft = drafted(outline: outline.merge("title" => "<script>alert('title')</script>",
                                           "points" => [ point.merge("question" => "<script>alert('question')</script>"), point ]),
                    sources: [ { url: "https://www.jw.org/en/", title: "<script>alert('source')</script>" } ])

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: draft, open: true))

    assert_no_selector "script", visible: :all
    assert_text "<script>alert('title')</script>"
    assert_text "Ask: <script>alert('question')</script>"
    assert_link "<script>alert('source')</script>"
  end

  test "sources show only title, host and link (no snippet)" do
    draft = drafted(sources: [ { url: "https://wol.jw.org/en/wol/d/r1/lp-e/1200275025", title: "Praying Together as a Family", cited_text: "An excerpt from the page." } ])

    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: draft, open: true))

    assert_selector "a[href='https://wol.jw.org/en/wol/d/r1/lp-e/1200275025'][target=_blank][rel~=noopener]", text: "Praying Together as a Family"
    assert_selector "li", exact_text: "Praying Together as a Family · wol.jw.org", normalize_ws: true
    assert_no_text "An excerpt from the page."
  end

  test "a source with no title shows its host as the link" do
    render_inline(FamilyStudies::AiPanelComponent.new(household: @household, user: @user, draft: drafted(sources: [ { url: "https://www.jw.org/en/library/", title: nil } ]), open: true))

    assert_link "jw.org", href: "https://www.jw.org/en/library/"
  end

  private
    def drafted(outline: self.outline, sources:)
      family_study_draft(household: @household, status: "drafted", outline: outline, sources: sources)
    end

    def outline
      {
        "title" => "Talking to Jehovah as a family",
        "opening" => { "scripture" => "Philippians 4:6, 7", "question" => "What could we tell Jehovah about this week?" },
        "points" => [ point, point.merge("heading" => "We can pray about anything", "scripture" => "1 Peter 5:7") ],
        "closing" => "Choose one thing to thank Jehovah for each day this week."
      }
    end

    def point
      { "heading" => "Jehovah listens to each of us", "scripture" => "Psalm 65:2", "question" => "Why does it matter that Jehovah hears even short prayers?" }
    end

    def dom_id(...) = ActionView::RecordIdentifier.dom_id(...)
end
