# Answers a personal study question (PersonalStudy::Question#answer_now). The question's id only: a prompt never goes
# in job arguments (docs/design/ai.md, Traps). One question per study at a time: they share the study's chat, and
# RubyLLM would fold a second prompt into the first's run, or resend the whole history.
class PersonalStudy::AnswerQuestionJob < ApplicationJob
  limits_concurrency key: ->(question_id) { PersonalStudy::Question.where(id: question_id).pick(:personal_study_id) || question_id }, duration: 15.minutes

  # A question deleted with its study before the job ran has nothing left to answer.
  def perform(question_id)
    PersonalStudy::Question.find_by(id: question_id)&.answer_now
  end
end
