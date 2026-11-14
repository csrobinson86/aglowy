class FamilyStudies::SessionsController < ApplicationController
  include HouseholdScoped

  before_action :set_study_session

  def show
  end

  private

  # The session through its study, so a session id paired with another study's id is a 404.
  def set_study_session
    @family_study = Current.household.family_studies.find(params[:family_study_id])
    @study_session = @family_study.sessions.find(params[:id])
    authorize @study_session
  end
end
