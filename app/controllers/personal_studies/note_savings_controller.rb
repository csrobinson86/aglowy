# Save to note on an answer card (docs/design/personal-study.md, Save to note). The study and its question are found
# through Current.user, so someone else's is a 404. Only an answered question can be saved; anything else is a 422.
# The card's footer becomes "Saved to note · Open note" and the study's note panel refreshes.
class PersonalStudies::NoteSavingsController < ApplicationController
  include HouseholdScoped

  before_action :set_question

  def create
    @question.save_to_note
    render turbo_stream: [
      turbo_stream.replace([ @question, :note_saving ], partial: "personal_studies/questions/note_saving", locals: { question: @question, household: Current.household }),
      turbo_stream.replace([ @question.personal_study, :note ], partial: "personal_studies/notes", locals: { personal_study: @question.personal_study })
    ]
  rescue PersonalStudy::Question::NotAnswered
    head :unprocessable_content
  end

  private
    def set_question
      personal_study = Current.user.personal_studies.find(params[:personal_study_id])
      authorize personal_study, :update?
      @question = personal_study.questions.find(params[:question_id])
    end
end
