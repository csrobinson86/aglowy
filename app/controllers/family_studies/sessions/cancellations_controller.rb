# Cancelling one session, and undoing it. The rest of the series isn't touched (scheduling rule 6).
class FamilyStudies::Sessions::CancellationsController < ApplicationController
  include HouseholdScoped

  before_action :set_study_session

  def create
    @study_session.cancel
    redirect_to study_session_path, notice: "Session cancelled."
  end

  def destroy
    @study_session.restore
    redirect_to study_session_path, notice: "Session restored."
  end

  private

  # The session through its study, so a session id paired with another study's id is a 404.
  # Cancelling is editing the session (docs/design/family-studies.md, Who can do what).
  def set_study_session
    @family_study = Current.household.family_studies.find(params[:family_study_id])
    @study_session = @family_study.sessions.find(params[:session_id])
    authorize @study_session, :update?
  end

  def study_session_path
    household_family_study_session_path(family_study_id: @family_study, id: @study_session)
  end
end
