# Keep in Notes: a week's study guide kept as one of the person's own notes, then opened there
# (docs/design/study-guide.md, Pages and routes). Found through Current.user, so another person's week is a 404 like a
# week with none (Trap 3), and anyone StudyGuidePolicy turns away gets a 404 too, as on the guide's page.
class StudyGuides::NotesController < ApplicationController
  include HouseholdScoped

  rescue_from(Pundit::NotAuthorizedError) { raise ActiveRecord::RecordNotFound }

  # Keeping it takes only reading it. Each keep makes a new note, the person's to change or delete.
  def create
    study_guide = Current.user.study_guides.preloaded.find_by!(week_of: params[:study_guide_week_of])
    authorize study_guide, :show?

    redirect_to household_personal_note_path(id: study_guide.keep_as_note), notice: "Kept in Notes.", status: :see_other
  end
end
