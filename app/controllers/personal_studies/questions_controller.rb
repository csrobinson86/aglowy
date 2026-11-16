# Asking in a study's conversation, and Stop while it's answered (docs/design/personal-study.md, Asking). The study is
# found through Current.user, so someone else's is a 404. A question refused (the day's limit, no AI access, or
# nothing typed) shows the study again with the reason.
class PersonalStudies::QuestionsController < ApplicationController
  include HouseholdScoped

  before_action :set_personal_study
  # The page shows the first-use notice in place of the box until then, but the server doesn't trust the UI
  # (docs/design/ai.md, First use).
  before_action { head :forbidden unless Current.user.accepted_ai_terms? }

  # Who's asking shapes the answer: a child in the household they're viewing gets simpler wording.
  def create
    @question = @personal_study.ask(params.expect(personal_study_question: [ :prompt ])[:prompt], by: Current.user, young_reader: Current.membership.child?)

    if @question.persisted?
      redirect_to household_personal_study_path(id: @personal_study, anchor: helpers.dom_id(@question)), status: :see_other
    else
      render "personal_studies/show", status: :unprocessable_content
    end
  end

  # Stops a question while it's asking; one already finished keeps its answer.
  def destroy
    question = @personal_study.questions.find(params[:id])
    question.stop

    redirect_to household_personal_study_path(id: @personal_study, anchor: helpers.dom_id(question)), status: :see_other
  end

  private
    def set_personal_study
      @personal_study = Current.user.personal_studies.preloaded.find(params[:personal_study_id])
      authorize @personal_study, :ask?
    end
end
