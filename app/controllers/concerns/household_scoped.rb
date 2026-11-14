module HouseholdScoped
  extend ActiveSupport::Concern

  included do
    layout "household"
    before_action :set_current_membership
  end

  private

  # Through Current.user, never Household.find: a non-member gets a 404 that
  # doesn't confirm the household exists (gotcha 6).
  def set_current_membership
    Current.membership = Current.user.memberships.active.find_by!(household_id: params[:household_id])
  end

  def default_url_options
    super.merge(household_id: Current.household)
  end
end
