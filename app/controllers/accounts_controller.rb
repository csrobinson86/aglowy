# The Profile section of account settings, at /account, for a person with no household. Everyone else gets Settings,
# opening on Profile in their first household by name (docs/design/settings.md, /account stays).
class AccountsController < ApplicationController
  include AccountScoped

  before_action { authorize @user }

  def edit
    if (membership = @memberships.first)
      redirect_to household_settings_profile_path(household_id: membership.household_id)
    end
  end

  def update
    if @user.update(user_params)
      redirect_to edit_account_path, notice: "Your profile is saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def user_params
      params.expect(user: %i[ name time_zone ])
    end
end
