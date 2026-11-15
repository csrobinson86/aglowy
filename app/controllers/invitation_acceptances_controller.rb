# /invitation?token=…, outside any household (docs/design/invitations.md, Accepting). The token is the permission:
# there's no membership to authorize against yet, so like SignupsController it skips Pundit.
class InvitationAcceptancesController < ApplicationController
  layout "focused"

  skip_before_action :authenticate_identity!, only: %i[ show create ]
  skip_after_action :verify_authorized

  before_action :set_invitation_signup

  # Both pages offer "Sign in to accept", which comes back here after signing in.
  def show
    store_location_for(:identity, request.fullpath)
    render :sign_in if Identity.exists?(email: @invitation_signup.email)
  end

  def create
    @invitation_signup.assign_attributes(invitation_signup_params)

    if @invitation_signup.save
      stored_location_for(:identity) # Reading it clears it: the link is used up, so a later sign-in mustn't return to it.
      sign_in @invitation_signup.identity
      redirect_to household_root_path(household_id: @invitation_signup.household), notice: "Welcome to the #{@invitation_signup.household.name}."
    elsif @invitation_signup.invitation
      render :show, status: :unprocessable_content
    else
      render_invalid
    end
  end

  private

  def set_invitation_signup
    @invitation_signup = InvitationSignup.new(token: params[:token])
    render_invalid unless @invitation_signup.invitation
  end

  # Says nothing about why, or which household (docs/design/invitations.md, Traps).
  def render_invalid
    render :invalid, status: :not_found
  end

  # Never the email: it comes from the invitation.
  def invitation_signup_params
    params.expect(invitation_signup: %i[ name password ])
  end
end
