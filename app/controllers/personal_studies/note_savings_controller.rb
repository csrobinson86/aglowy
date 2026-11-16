# Save to notes on an answer card (docs/design/personal-study.md, Save to notes). The study and its question are found
# through Current.user, so someone else's is a 404. Only an answered question can be saved; anything else is a 422.
class PersonalStudies::NoteSavingsController < ApplicationController
  include HouseholdScoped

  before_action :set_question

  def create
    @question.save_to_notes
    render turbo_stream: turbo_stream.replace([ @question.personal_study, :notes ], partial: "personal_studies/notes", locals: { personal_study: @question.personal_study })
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
