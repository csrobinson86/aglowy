require "application_system_test_case"

# The AI panel beside the Schedule form (docs/design/family-studies.md, AI helper). The test queue adapter only
# enqueues the draft's job; write_draft runs it here with the AI stubbed, so nothing calls an AI provider.
class FamilyStudyAiTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

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
    assert_no_selector "turbo-cable-stream-source", visible: :all
    assert_predicate households(:home).family_study_drafts.sole, :stopped?
  end

  test "a child sees no panel" do
    sign_in identities(:eli)
    visit new_household_family_study_url(household_id: households(:home))

    assert_text "You can't do that in this household."
    assert_no_selector "turbo-frame#ai_panel"
    assert_no_text "Plan it with AI"
  end

  private
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
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
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
