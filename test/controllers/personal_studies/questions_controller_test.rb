require "test_helper"

# Asking and stopping in a study's conversation (docs/design/personal-study.md, Pages and routes: Ask and Stop).
class PersonalStudies::QuestionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @home = households(:home)
    @study = personal_studies(:head_suffering)
    users(:head).accept_ai_terms(understood: true)
  end

  test "creates and enqueues" do
    sign_in identities(:head)

    assert_difference [ -> { @study.questions.count }, -> { Ai::Use.count } ], 1 do
      assert_enqueued_jobs(1, only: PersonalStudy::AnswerQuestionJob) { ask "How does the ransom fit in?" }
    end

    question = @study.questions.sole
    assert_redirected_to household_personal_study_path(household_id: @home, id: @study, anchor: "personal_study_question_#{question.id}")
    assert_response :see_other
    assert_equal "How does the ransom fit in?", question.prompt
    assert_predicate question, :asking?
    assert_not_predicate question, :young_reader?

    follow_redirect!
    assert_select "#personal_study_question_#{question.id}", text: /How does the ransom fit in\?/ do
      assert_select "ul[aria-live=polite]"
      assert_select "button", text: "Stop"
    end
    assert_select "main", text: /29 of 30 questions left today/
  end

  test "31st: limit message" do
    30.times { Ai::Use.create!(user: users(:head), purpose: "personal_study") }
    sign_in identities(:head)

    assert_no_difference [ -> { PersonalStudy::Question.count }, -> { Ai::Use.count } ] do
      assert_no_enqueued_jobs { ask "One more question" }
    end

    assert_response :unprocessable_content
    assert_select "main", text: /You've asked 30 questions today. You can ask again after midnight./
    assert_select "textarea[name='personal_study_question[prompt]'][disabled]"
    assert_select "button[type=submit][disabled]", text: "Ask"
    assert_select ".study-question", count: 0
  end

  test "a blank question shows the page again with the reason" do
    sign_in identities(:head)

    assert_no_difference -> { PersonalStudy::Question.count } do
      ask "   "
    end

    assert_response :unprocessable_content
    assert_select "textarea[name='personal_study_question[prompt]'][aria-invalid=true]"
    assert_select "main", text: /can't be blank/
  end

  test "without terms: 403" do
    users(:head).ai_acceptances.delete_all
    sign_in identities(:head)

    assert_no_difference -> { PersonalStudy::Question.count } do
      ask "How does the ransom fit in?"
    end

    assert_response :forbidden
  end

  test "another person's study: 404" do
    users(:spouse).accept_ai_terms(understood: true)
    sign_in identities(:spouse)

    assert_no_difference -> { PersonalStudy::Question.count } do
      ask "How does the ransom fit in?"
    end

    assert_response :not_found
  end

  test "stop" do
    question = personal_study_question(@study)
    sign_in identities(:head)

    delete household_personal_study_question_path(household_id: @home, personal_study_id: @study, id: question)

    assert_redirected_to household_personal_study_path(household_id: @home, id: @study, anchor: "personal_study_question_#{question.id}")
    assert_predicate question.reload, :stopped?
  end

  test "stop leaves a finished question alone" do
    question = personal_study_question(@study, status: "answered", answer: { "paragraphs" => [ "An answer." ] })
    sign_in identities(:head)

    delete household_personal_study_question_path(household_id: @home, personal_study_id: @study, id: question)

    assert_predicate question.reload, :answered?
  end

  test "stop in another person's study: 404" do
    question = personal_study_question(@study)
    users(:spouse).accept_ai_terms(understood: true)
    sign_in identities(:spouse)

    delete household_personal_study_question_path(household_id: @home, personal_study_id: @study, id: question)

    assert_response :not_found
    assert_predicate question.reload, :asking?
  end

  # Eli is an adult in another household, so may ask, and a child in this one, which shapes the answer.
  test "asked from a household where they're a child, the answer is for a young reader" do
    Membership.create!(household: households(:parents), user: users(:eli), role: "adult")
    users(:eli).accept_ai_terms(understood: true)
    study = users(:eli).personal_studies.create!(title: "Why do we pray?")
    sign_in identities(:eli)

    post household_personal_study_questions_path(household_id: @home, personal_study_id: study), params: { personal_study_question: { prompt: "Why pray?" } }

    assert_predicate study.questions.sole, :young_reader?
  end

  test "a child without AI for personal study is refused with the reason" do
    users(:eli).accept_ai_terms(understood: true)
    study = users(:eli).personal_studies.create!(title: "Why do we pray?")
    sign_in identities(:eli)

    assert_no_difference -> { PersonalStudy::Question.count } do
      post household_personal_study_questions_path(household_id: @home, personal_study_id: study), params: { personal_study_question: { prompt: "Why pray?" } }
    end

    assert_response :unprocessable_content
    assert_select "main", text: /Ask a head to turn on AI for your personal study./
    assert_select "textarea[name='personal_study_question[prompt]'][disabled]"
  end

  private
    def ask(prompt)
      post household_personal_study_questions_path(household_id: @home, personal_study_id: @study), params: { personal_study_question: { prompt: } }
    end
end
