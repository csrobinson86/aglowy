# Settings → My households: the person's own seats, and leaving one (docs/design/settings.md, Leaving). Leaving
# deactivates the seat, never deletes it, and the last head is refused by Membership#deactivate.
class Settings::MembershipsController < ApplicationController
  include HouseholdScoped

  def index
    authorize Membership
    @memberships = Current.user.memberships.active.by_household_name
  end

  def destroy
    membership = Current.user.memberships.active.find(params[:id])
    authorize membership, :leave?

    if membership.deactivate
      redirect_to after_leaving_path(membership), notice: "You left the #{membership.household.name}.", status: :see_other
    else
      redirect_to household_settings_memberships_path, alert: "Make someone else a head before you leave.", status: :see_other
    end
  end

  private
    # Leaving the household in the URL leaves nothing to come back to here.
    def after_leaving_path(membership)
      membership == Current.membership ? households_path(household_id: nil) : household_settings_memberships_path
    end
end
