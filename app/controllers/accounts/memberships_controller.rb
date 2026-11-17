# Leaving a household from account settings' "My households" (docs/design/invitations.md, Account settings).
# Leaving deactivates the seat, never deletes it, so rejoining later reactivates the same row.
class Accounts::MembershipsController < ApplicationController
  include AccountScoped

  before_action :set_membership

  def destroy
    if @membership.deactivate
      redirect_to households_path, notice: "You left the #{@membership.household.name}.", status: :see_other
    else
      redirect_to edit_account_path, alert: "Make someone else a head before you leave.", status: :see_other
    end
  end

  private
    def set_membership
      @membership = Current.user.memberships.active.find(params[:id])
      authorize @membership, :leave?
    end
end
