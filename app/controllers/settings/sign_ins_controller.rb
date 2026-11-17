# Settings → Signing in (docs/design/invitations.md, Account settings). An email change waits for the new address to
# be confirmed (Devise's reconfirmable); a child's username-only login changes only its password (IdentityPolicy).
class Settings::SignInsController < ApplicationController
  include HouseholdScoped

  before_action { authorize @identity = Current.identity, :update? }

  def show
  end

  def update
    if @identity.update_with_password(permitted_attributes(@identity))
      # A new password changes the session's salt; without this the person is signed out on their next request.
      bypass_sign_in @identity
      redirect_to household_settings_sign_in_path, notice: "Your sign-in details are saved."
    else
      render :show, status: :unprocessable_content
    end
  end
end
