# Inviting someone to the household by email, and resending or cancelling an open invitation from the Members page
# (docs/design/invitations.md, "Inviting"). Accepting is InvitationAcceptancesController, outside the household.
class InvitationsController < ApplicationController
  include HouseholdScoped

  rate_limit to: 20, within: 1.hour, only: %i[ create update ]

  before_action :set_invitation, only: %i[ update destroy ]

  def new
    authorize @invitation = Current.household.invitations.build
  end

  def create
    @invitation = Current.household.invitations.build(invitation_params.merge(invited_by: Current.user))
    authorize @invitation, :create_with_role?

    if @invitation.save
      @invitation.deliver_later
      redirect_to household_members_path, notice: "Invitation sent to #{@invitation.email}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @invitation.resend
    redirect_to household_members_path, notice: "Invitation sent again to #{@invitation.email}."
  end

  def destroy
    @invitation.cancel
    redirect_to household_members_path, notice: "Invitation to #{@invitation.email} cancelled.", status: :see_other
  end

  private

  # Through Current.household, so another household's invitation is a 404.
  def set_invitation
    authorize @invitation = Current.household.invitations.find(params[:id])
  end

  # The role is guarded by InvitationPolicy#create_with_role?; the household and inviter never come from the params.
  def invitation_params
    params.expect(invitation: %i[ email role ])
  end
end
