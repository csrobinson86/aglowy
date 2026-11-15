# The Signing in section of account settings: its form posts here, and the page is the account settings page.
# An email change waits for the new address to be confirmed (Devise's reconfirmable).
class Accounts::SignInsController < ApplicationController
  include AccountScoped

  before_action { authorize @identity }

  def edit
    render "accounts/edit"
  end

  def update
    if @identity.update_with_password(permitted_attributes(@identity))
      # A new password changes the session's salt; without this the person is signed out on their next request.
      bypass_sign_in @identity
      redirect_to edit_account_path(return_to_params), notice: "Your sign-in details are saved."
    else
      render "accounts/edit", status: :unprocessable_content
    end
  end
end
