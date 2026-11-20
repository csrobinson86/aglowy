require "application_system_test_case"

# A head turns on personal study with AI for a child, in Settings → Children, and reads the child's studies
# (docs/design/personal-study.md, Children). The question's job runs here with the AI stubbed; nothing calls a provider.
class PersonalStudyChildrenTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @study = users(:eli).personal_studies.create!(title: "How did life begin?")
    @study.with_lock { @study.start_note }.update!(body: "<p>Ask about Genesis 1.</p>")
    @study.tag_with("creation", by: users(:eli))
  end

  test "a head turns it on; the child asks as a young reader; the head reads the question and notes" do
    sign_in identities(:head)
    visit household_settings_children_url(household_id: households(:home))

    within("#study-ai") do
      assert_selector "h3", text: "Personal study with AI"
      within(child_row("Sofia Child")) { assert_text "Needs a login first" }
      within(child_row("Eli Child")) do
        assert_text "Off"
        click_on "Turn on"
      end
    end

    assert_text "Personal study with AI turned on for Eli Child."
    within(child_row("Eli Child")) do
      assert_text "On"
      assert_text "Turned on by Hannah on"
      assert_button "Turn off"
    end
    assert_accessible
    capture_screens("child-study-ai-setting", scroll_to: "#study-ai")

    sign_out :identity
    sign_in identities(:eli)
    visit household_personal_studies_url(household_id: households(:home))

    assert_selector ".Banner", text: "Your parents can read your personal study, including what you ask and your notes."
    click_on "How did life begin?"
    assert_selector ".Banner", text: "Your parents can read your personal study, including what you ask and your notes."
    check "I understand how AI drafts work"
    click_on "Turn on AI drafts"
    fill_in "Ask a question", with: "Who made the animals?"
    click_on "Ask"
    within(".study-question") { assert_button "Stop" }

    request = answer("personal_study_answer")

    assert_includes request, PersonalStudy::Question::YOUNG_READER
    within(".study-question") { assert_text "The publications explain that suffering didn't start with God." }
    assert_accessible

    sign_out :identity
    sign_in identities(:head)
    visit household_members_url(household_id: households(:home))
    find("#members a[aria-label=\"Read Eli Child's personal study\"]", text: "Personal study").click

    assert_selector "h1", text: "Eli Child's personal study"
    assert_selector ".Label", text: "#creation"
    assert_accessible
    click_on "How did life begin?"

    assert_selector "h1", text: "How did life begin?"
    assert_selector ".study-question p", text: "Who made the animals?"
    assert_text "The publications explain that suffering didn't start with God."
    within("#study-notes") { assert_text "Ask about Genesis 1." }
    assert_selector ".Label", text: "#creation"
    assert_no_button "Save to note"
    assert_no_field "Ask a follow-up"
    assert_accessible
    capture_screens("child-personal-study-read-by-head")
  end

  test "an adult sees the state and that only a head can turn it on" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))
    sign_in identities(:spouse)
    visit household_settings_children_url(household_id: households(:home))

    within("#study-ai") do
      assert_text "Only a head can turn this on."
      within(child_row("Eli Child")) { assert_text "On" }
      assert_no_button "Turn off"
    end
    assert_accessible
    capture_screens("child-study-ai-setting-adult", scroll_to: "#study-ai")
  end

  test "turning it off disables the child's ask box and ends the head's view" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))
    users(:eli).accept_ai_terms(understood: "1")
    sign_in identities(:head)
    visit household_settings_children_url(household_id: households(:home))

    within(child_row("Eli Child")) { click_on "Turn off" }

    assert_text "Personal study with AI turned off for Eli Child."
    within(child_row("Eli Child")) { assert_button "Turn on" }
    visit household_members_url(household_id: households(:home))
    assert_selector "#members", text: "Eli Child"
    assert_no_selector "#members a", text: "Personal study"
    visit household_member_personal_study_url(household_id: households(:home), member_id: memberships(:eli_in_home), id: @study)
    assert_no_text "How did life begin?"

    sign_out :identity
    sign_in identities(:eli)
    visit household_personal_study_url(household_id: households(:home), id: @study)

    assert_field "Ask a question", disabled: true
    assert_text "Ask a head to turn on AI for your personal study."
    assert_no_text "Your parents can read your personal study"
    within("section[aria-labelledby=study-note]") { assert_link "How did life begin?" }
  end

  private
    def child_row(name)
      find("#study-ai li", text: name)
    end

    # Runs the question's job with moderation passing and Chat#ask_within_purpose standing in for the provider, which
    # answers with the saved reply (test/fixtures/files/ai/). Returns the text the AI was asked.
    def answer(name)
      question = PersonalStudy::Question.asking.sole
      chat = question.personal_study.chat
      ask_for_real = chat.method(:ask_within_purpose)
      body = JSON.parse(file_fixture("ai/#{name}.json").read)
      asked = nil
      ask = lambda do |text, stream:|
        asked = text
        response = Faraday::Response.new(Faraday::Env.from(status: 200, body: body))
        chat.to_llm.provider.connection.stub(:post, ->(*, **) { response }) { ask_for_real.call(text) }
      end

      Ai::Moderation.stub(:flagged?, false) do
        chat.stub(:ask_within_purpose, ask) do
          PersonalStudy::Question.stub(:find_by, question) { perform_enqueued_jobs }
        end
      end
      asked
    end
end
