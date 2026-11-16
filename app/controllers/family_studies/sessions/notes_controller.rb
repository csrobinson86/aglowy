class FamilyStudies::Sessions::NotesController < ApplicationController
  include HouseholdScoped

  before_action :set_study_session

  def edit
  end

  # References typed by hand are linked. Notes with anything but scripture links show the form again with the message.
  def update
    @study_session.assign_attributes(notes_params)
    @study_session.link_scriptures

    if @study_session.save
      redirect_to household_family_study_session_path(family_study_id: @family_study, id: @study_session), notice: "Notes saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  # The session through its study, so a session id paired with another study's id is a 404.
  def set_study_session
    @family_study = Current.household.family_studies.find(params[:family_study_id])
    @study_session = @family_study.sessions.find(params[:session_id])
    authorize @study_session
  end

  def notes_params
    params.expect(family_study_session: [ :notes ])
  end
end
