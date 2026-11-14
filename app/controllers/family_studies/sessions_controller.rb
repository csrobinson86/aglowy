class FamilyStudies::SessionsController < ApplicationController
  include HouseholdScoped

  before_action :set_study_session

  def show
  end

  def edit
    @edit = FamilyStudy::Session::Edit.new(@study_session)
  end

  # This session only: the rest of the series isn't touched (scheduling rule 7).
  def update
    @edit = FamilyStudy::Session::Edit.new(@study_session, **edit_params)

    if @edit.save
      redirect_to household_family_study_session_path(family_study_id: @family_study, id: @study_session), notice: "Session updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  # The session through its study, so a session id paired with another study's id is a 404.
  def set_study_session
    @family_study = Current.household.family_studies.find(params[:family_study_id])
    @study_session = @family_study.sessions.find(params[:id])
    authorize @study_session
  end

  def edit_params
    params.expect(family_study_session_edit: %i[ topic starts_on starts_at ]).to_h.symbolize_keys
  end
end
