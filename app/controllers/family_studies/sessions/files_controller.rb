# Files the drop zone has uploaded become file resources on the session.
class FamilyStudies::Sessions::FilesController < ApplicationController
  include HouseholdScoped

  before_action :set_study_session

  def create
    resources = @study_session.add_files(params.expect(files: []))

    if resources.empty?
      redirect_to study_session_path, alert: "Those files couldn't be found. Upload them again."
    elsif (refused = resources.find { it.errors.any? })
      redirect_to study_session_path, alert: "#{refused.title} wasn't added: it #{refused.errors[:file].to_sentence}."
    else
      redirect_to study_session_path, notice: "#{helpers.pluralize(resources.size, "file")} added."
    end
  end

  private

  # Adding a resource is editing the session (docs/design/family-studies.md, Who can do what).
  def set_study_session
    @family_study = Current.household.family_studies.find(params[:family_study_id])
    @study_session = @family_study.sessions.find(params[:session_id])
    authorize @study_session, :update?
  end

  def study_session_path
    household_family_study_session_path(family_study_id: @family_study, id: @study_session)
  end
end
