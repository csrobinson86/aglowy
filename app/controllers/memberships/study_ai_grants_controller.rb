# Settings → Children → "Personal study with AI": a head turns it on or off for one child
# (docs/design/personal-study.md, Children). Turning it off keeps the child's studies; it stops new questions and
# ends heads' view of them.
class Memberships::StudyAiGrantsController < ApplicationController
  include HouseholdScoped

  before_action :set_child

  def create
    if @child.grant_study_ai(by: Current.user).persisted?
      redirect_to_children notice: "Personal study with AI turned on for #{@child.user.name}."
    else
      redirect_to_children alert: "#{@child.user.name} needs a login first."
    end
  end

  def destroy
    @child.revoke_study_ai
    redirect_to_children notice: "Personal study with AI turned off for #{@child.user.name}.", status: :see_other
  end

  private

  # Through Current.household, so another household's member, or a seat that isn't a child's, is a 404.
  def set_child
    @child = Current.household.memberships.active.child.preloaded.find(params[:membership_id])
    authorize @child, policy_class: Memberships::StudyAiGrantPolicy
  end

  def redirect_to_children(**options)
    redirect_to household_settings_children_path, **options
  end
end
