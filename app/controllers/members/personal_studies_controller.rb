# A head's read-only view of a child's personal studies: the list, and each study with its conversation, sources,
# note and tags (docs/design/personal-study.md, Children). Only for a head here, while the child has a study AI
# grant here (ChildStudyPolicy); anyone else, and any study that isn't the child's, gets a 404.
class Members::PersonalStudiesController < ApplicationController
  include HouseholdScoped

  rescue_from(Pundit::NotAuthorizedError) { raise ActiveRecord::RecordNotFound }

  before_action :set_child

  def index
    @personal_studies = @child.user.personal_studies.preloaded.recent_first
  end

  def show
    @personal_study = @child.user.personal_studies.preloaded.find(params[:id])
  end

  private

  # Through Current.household, so another household's member is a 404 before the policy runs.
  def set_child
    @child = Current.household.memberships.active.preloaded.find(params[:member_id])
    authorize @child, policy_class: ChildStudyPolicy
  end
end
