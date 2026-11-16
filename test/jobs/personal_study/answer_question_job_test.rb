require "test_helper"

class PersonalStudy::AnswerQuestionJobTest < ActiveJob::TestCase
  test "questions in the same study are answered one at a time; another study's can run beside them" do
    first = personal_study_question
    second = personal_study_question
    elsewhere = personal_study_question(personal_studies(:head_daniel))

    assert_equal 1, PersonalStudy::AnswerQuestionJob.concurrency_limit
    assert_equal job(first).concurrency_key, job(second).concurrency_key
    assert_not_equal job(first).concurrency_key, job(elsewhere).concurrency_key
  end

  test "a question deleted with its study before the job ran is skipped" do
    question = personal_study_question
    personal_studies(:head_suffering).destroy!

    assert_nothing_raised { PersonalStudy::AnswerQuestionJob.perform_now(question.id) }
    assert_not_nil job(question).concurrency_key
  end

  private
    def job(question)
      PersonalStudy::AnswerQuestionJob.new(question.id)
    end
end
