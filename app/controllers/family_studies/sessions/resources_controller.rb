class FamilyStudies::Sessions::ResourcesController < ApplicationController
  include HouseholdScoped

  before_action :set_study_session

  def create
    @resource = @study_session.resources.new(resource_params)

    if @resource.save
      redirect_to study_session_path, notice: "Link added."
    else
      render "family_studies/sessions/show", status: :unprocessable_content
    end
  end

  # Through the session, so another session's or household's resource is a 404.
  def destroy
    @study_session.resources.find(params[:id]).destroy!
    redirect_to study_session_path, notice: "Link removed."
  end

  private

  # The session through its study, so a session id paired with another study's id is a 404.
  # Adding or removing a resource is editing the session (docs/design/family-studies.md, Who can do what).
  def set_study_session
    @family_study = Current.household.family_studies.find(params[:family_study_id])
    @study_session = @family_study.sessions.find(params[:session_id])
    authorize @study_session, :update?
  end

  def resource_params
    params.expect(family_study_resource: [ :url ])
  end

  def study_session_path
    household_family_study_session_path(family_study_id: @family_study, id: @study_session)
  end
end
