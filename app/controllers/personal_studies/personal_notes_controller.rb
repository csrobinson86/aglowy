# Save as a note on an answer card (docs/design/notes.md, Save an AI answer as a note). The study and its question are
# found through Current.user, so someone else's is a 404, and the person must be able to read the study and make a
# note. Only an answered question can be saved; anything else is a 422.
class PersonalStudies::PersonalNotesController < ApplicationController
  include HouseholdScoped

  before_action :set_question

  def create
    redirect_to household_personal_note_path(id: @question.save_as_note), notice: "Saved as a note."
  rescue PersonalStudy::Question::NotAnswered
    head :unprocessable_content
  end

  private
    def set_question
      personal_study = Current.user.personal_studies.find(params[:personal_study_id])
      authorize personal_study, :show?
      authorize Current.user.personal_notes.new, :create?
      @question = personal_study.questions.find(params[:question_id])
    end
end
