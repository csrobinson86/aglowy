# The study's note beside the conversation, started and edited in place in its panel's Turbo Frame
# (docs/design/personal-study.md, The study page: Study note). The study is found through Current.user, so another
# person's, or a child's that a head can read, is a 404. Only the body is saved here: title, color and tags are in Notes.
class PersonalStudies::NotesController < ApplicationController
  include HouseholdScoped

  before_action :set_personal_study
  before_action :set_note, only: %i[ edit update ]

  # Under the study's lock, as Save to note takes it, so the two find one note between them.
  def create
    @personal_study.with_lock { @personal_study.start_note }
    redirect_to edit_household_personal_study_note_path(personal_study_id: @personal_study)
  end

  def edit
  end

  # Saved only when the form's base is the note as it is now (docs/design/notes.md, A note: the version check). A stale
  # save, after Save to note appended an answer say, writes nothing and shows the note as it is now, with what the form
  # sent under "What you wrote".
  def update
    attributes = params.expect(personal_note: %i[ body ])

    if @note.revise(attributes, base: params.dig(:personal_note, :base))
      redirect_to household_personal_study_path(id: @personal_study)
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::StaleObjectError
    @written = PersonalNote.new(attributes)
    render :edit, status: :conflict
  end

  private
    def set_personal_study
      @personal_study = Current.user.personal_studies.find(params[:personal_study_id])
      authorize @personal_study, :update?
    end

    def set_note
      @note = @personal_study.note or raise ActiveRecord::RecordNotFound
    end
end
