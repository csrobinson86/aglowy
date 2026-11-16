require "application_system_test_case"

# Asking in a study's conversation (docs/design/personal-study.md, The study page). The test queue adapter only
# enqueues the question's job; answer runs it here with the AI stubbed, so nothing calls an AI provider.
class PersonalStudyAiTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    users(:head).accept_ai_terms(understood: "1")
    sign_in identities(:head)
    @study = personal_studies(:head_suffering)
  end

  test "ask, see progress, then the answer with links; ask a Keep digging chip and see the not-found answer" do
    visit household_personal_study_url(household_id: households(:home), id: @study)

    assert_text "Answers use only jw.org and wol.jw.org, in the AI's own words, with links. 30 of 30 questions left today."
    fill_in "Ask a question", with: "Why does Jehovah allow suffering, and will it ever end?"
    click_on "Ask"

    within(question_card("Why does Jehovah allow suffering, and will it ever end?")) do
      assert_selector "ul[aria-live=polite] li", text: "Searching jw.org and wol.jw.org…"
      assert_button "Stop"
    end
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    answer("personal_study_answer", midway: lambda {
      assert_selector "ul[aria-live=polite] li", text: "Writing the answer…"
      assert_no_text "didn't start with God"
    })

    within(question_card("Why does Jehovah allow suffering, and will it ever end?")) do
      assert_text "From jw.org and wol.jw.org"
      assert_text "The publications explain that suffering didn't start with God."
      assert_link "Genesis 3:1-6", href: %r{\Ahttps://www.jw.org/finder}
      assert_link "Revelation 21:3, 4"
      assert_link "Why Does God Allow Suffering?", href: "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/"
      assert_text "The Issue Raised in Eden · wol.jw.org"
      assert_text "Check each point against its page."
      assert_no_button "Stop"
    end
    within("section[aria-labelledby=study-sources]") { assert_selector "li", count: 3 }
    assert_text "1 question · 3 pages linked"

    click_on "How does the ransom fit in?"
    assert_field "Ask a follow-up", with: "How does the ransom fit in?"
    click_on "Ask"
    assert_selector ".study-question p", exact_text: "How does the ransom fit in?"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    answer("personal_study_not_found")

    within(question_card("How does the ransom fit in?")) do
      assert_selector ".color-bg-subtle", text: "I couldn't find jw.org or wol.jw.org giving a length of time, so I won't guess one."
      assert_link "Matthew 24:36"
      assert_link "Jehovah's Patience"
    end
    within("section[aria-labelledby=study-sources]") do
      assert_selector "li", count: 4
      assert_text "Titles and links only. Open a page to read it on jw.org."
    end
    assert_text "28 of 30 questions left today."
    assert_accessible
    capture_screens("personal-study")
    capture_screens("personal-study-ask", scroll_to: "#study-ask")
  end

  test "at 30, the box is disabled with the message" do
    30.times { Ai::Use.create!(user: users(:head), purpose: "personal_study") }

    visit household_personal_study_url(household_id: households(:home), id: @study)

    assert_field "Ask a question", disabled: true
    assert_button "Ask", disabled: true
    assert_text "You've asked 30 questions today. You can ask again after midnight."
    assert_accessible
    capture_screens("personal-study-limit", scroll_to: "#study-ask")
  end

  test "on a phone notes and sources come under the conversation, and the answer's buttons are 44px" do
    personal_study_question(@study, status: "answered", sources: [ { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" } ],
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering (James 1:13)." ], "next_questions" => [ "What did Job learn?" ] })
    personal_study_question(@study, prompt: "How does the ransom fit in?")
    visit household_personal_study_url(household_id: households(:home), id: @study)
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
    emulate_touch(true)

    assert_operator find("section[aria-labelledby=study-sources]").evaluate_script("this.getBoundingClientRect().top"), :>,
      find("#study-ask").evaluate_script("this.getBoundingClientRect().top")
    [ find_button("What did Job learn?"), find_button("Stop") ].each do |button|
      assert_operator button.evaluate_script("this.offsetHeight"), :>=, 44, "#{button.text} is too small to tap"
    end
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
  ensure
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "without the AI terms, the first-use notice shows in place of the ask box, and accepting it brings the box" do
    users(:head).ai_acceptances.delete_all

    visit household_personal_study_url(household_id: households(:home), id: @study)

    assert_no_field "Ask a question"
    assert_selector "h2", text: "Before you use AI"
    assert_accessible
    capture_screens("personal-study-terms", scroll_to: "#study-ask")
    check "I understand how AI drafts work"
    click_on "Turn on AI drafts"

    assert_field "Ask a question"
    assert_current_path household_personal_study_path(household_id: households(:home), id: @study)
  end

  test "a new study with a first question asks it straight away" do
    visit new_household_personal_study_url(household_id: households(:home))

    fill_in "Title", with: "Why do we pray?"
    fill_in "First question", with: "Why does Jehovah want us to pray?"
    click_on "Start study"

    assert_selector "h1", text: "Why do we pray?"
    within(question_card("Why does Jehovah want us to pray?")) do
      assert_selector "ul[aria-live=polite] li", text: "Searching jw.org and wol.jw.org…"
    end
    assert_enqueued_jobs 1, only: PersonalStudy::AnswerQuestionJob
  end

  test "save an answer to notes and see it with scripture links" do
    @study.update!(notes: "<p>Start with Job.</p>")
    personal_study_question(@study, status: "answered", sources: [ { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" } ],
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering (James 1:13)." ], "next_questions" => [] })
    visit household_personal_study_url(household_id: households(:home), id: @study)

    within(question_card("Why does Jehovah allow suffering?")) { click_on "Save to notes" }

    within("section[aria-labelledby=my-notes]") do
      assert_text "Saved"
      within("lexxy-editor") do
        assert_text "Start with Job."
        assert_text "Jehovah never causes suffering"
        assert_selector ".scripture-link", text: "James 1:13"
        assert_text "Pages:"
        assert_link "Why Does God Allow Suffering?"
      end
    end
    assert_accessible
    capture_screens("personal-study-saved-to-notes", scroll_to: "#my-notes")

    visit household_personal_study_url(household_id: households(:home), id: @study)
    within("section[aria-labelledby=my-notes] lexxy-editor") { assert_text "Jehovah never causes suffering" }
  end

  test "plan a family study and see the prefilled box" do
    personal_study_question(@study, prompt: "How does the ransom fit in?")
    visit household_personal_study_url(household_id: households(:home), id: @study)

    click_on "Plan a family study from this"

    assert_selector "h1", text: "Schedule a family study"
    within("turbo-frame#ai_panel") do
      assert_field "What should the study be about?", with: "Why does Jehovah allow suffering?: How does the ransom fit in?"
      assert_button "Draft outline"
    end
    assert_equal 0, FamilyStudy::Draft.count
    assert_accessible
    capture_screens("plan-family-study-from-study", scroll_to: "turbo-frame#ai_panel")
  end

  test "a child sees no plan button" do
    child = Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    study = users(:child).personal_studies.create!(title: "Why do we pray?")
    sign_out :identity
    sign_in child

    visit household_personal_study_url(household_id: households(:home), id: study)

    assert_selector "h1", text: "Why do we pray?"
    assert_no_link "Plan a family study from this"
  end

  private
    # A question's card, by its question: an earlier answer's "Keep digging" chip can have the same words.
    def question_card(prompt)
      find(".study-question") { it.has_selector?("p", exact_text: prompt, wait: false) }
    end

    # Runs the question's job here, with moderation passing and Chat#ask_within_purpose standing in for the provider:
    # it streams the saved reply's text (test/fixtures/files/ai/), calls +midway+ after the first chunk, then answers
    # with the saved reply as the provider's HTTP response would arrive. No test calls a provider.
    def answer(name, midway: -> { })
      question = PersonalStudy::Question.asking.sole
      chat = question.personal_study.chat
      ask_for_real = chat.method(:ask_within_purpose)
      body = JSON.parse(file_fixture("ai/#{name}.json").read)
      ask = lambda do |text, stream:|
        body["content"].filter_map { it["text"] }.each_with_index do |chunk, index|
          stream.call(RubyLLM::Chunk.new(role: :assistant, content: chunk))
          midway.call if index.zero?
        end
        response = Faraday::Response.new(Faraday::Env.from(status: 200, body: body))
        chat.to_llm.provider.connection.stub(:post, ->(*, **) { response }) { ask_for_real.call(text) }
      end

      Ai::Moderation.stub(:flagged?, false) do
        chat.stub(:ask_within_purpose, ask) do
          PersonalStudy::Question.stub(:find_by, question) { perform_enqueued_jobs }
        end
      end
    end
end
