# /invitation?token=…, outside any household (docs/design/invitations.md, Accepting). The token is the permission:
# there's no membership to authorize against yet, so like SignupsController it skips Pundit. Signed out, it's the
# new-account form (InvitationSignup); signed in, it's Join or Decline (InvitationAcceptance).
class InvitationAcceptancesController < ApplicationController
  layout "focused"

  skip_before_action :authenticate_identity!, only: %i[ show create ]
  skip_after_action :verify_authorized

  before_action :set_invitation_signup, unless: :identity_signed_in?
  before_action :set_invitation_acceptance, if: :identity_signed_in?
  before_action :require_invited_identity, only: %i[ create destroy ], if: :identity_signed_in?

  def show
    if identity_signed_in?
      render @invitation_acceptance.for_identity? ? :confirm : :wrong_email
    else
      # Both signed-out pages offer "Sign in to accept", which comes back here after signing in.
      store_location_for(:identity, request.fullpath)
      render :sign_in if Identity.exists?(email: @invitation_signup.email)
    end
  end

  def create
    identity_signed_in? ? join : sign_up
  end

  def destroy
    if @invitation_acceptance.decline
      redirect_to households_path, notice: "Invitation declined."
    else
      render_invalid
    end
  end

  private

  def set_invitation_signup
    @invitation_signup = InvitationSignup.new(token: params[:token])
    render_invalid unless @invitation_signup.invitation
  end

  def set_invitation_acceptance
    @invitation_acceptance = InvitationAcceptance.new(token: params[:token], identity: Current.identity)
    render_invalid unless @invitation_acceptance.invitation
  end

  # Someone signed in with another email can't answer it, and isn't told more than the page already shows.
  def require_invited_identity
    render_invalid unless @invitation_acceptance.for_identity?
  end

  def join
    if @invitation_acceptance.join
      redirect_to household_root_path(household_id: @invitation_acceptance.household), notice: "Welcome to the #{@invitation_acceptance.household.name}."
    else
      render_invalid
    end
  end

  def sign_up
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

  # Says nothing about why, or which household (docs/design/invitations.md, Traps).
  def render_invalid
    render :invalid, status: :not_found
  end

  # Never the email: it comes from the invitation.
  def invitation_signup_params
    params.expect(invitation_signup: %i[ name password ])
  end
end
