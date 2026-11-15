# /password_setup?token=…, outside any household: a child chooses a password from the link a head or adult made
# (docs/design/invitations.md, Child logins). The token is the permission, so like InvitationAcceptancesController
# it skips Pundit, and a signed-out visitor is welcome.
class PasswordSetupsController < ApplicationController
  layout "focused"

  skip_before_action :authenticate_identity!
  skip_after_action :verify_authorized

  before_action :no_store
  before_action :set_password_setup

  def edit
  end

  def update
    @password_setup.assign_attributes(password_setup_params)

    if @password_setup.save
      sign_in @password_setup.identity
      redirect_to after_sign_in_path_for(@password_setup.identity), notice: "Your password is saved."
    elsif @password_setup.identity
      render :edit, status: :unprocessable_content
    else
      render_invalid
    end
  end

  private
    def set_password_setup
      @password_setup = Identity::PasswordSetup.new(token: params[:token])
      render_invalid unless @password_setup.identity
    end

    def render_invalid
      render :invalid, status: :not_found
    end

    def password_setup_params
      params.expect(identity_password_setup: %i[ password password_confirmation ])
    end
end
