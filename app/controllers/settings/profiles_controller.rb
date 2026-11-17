# Settings → Profile: the person's name and time zone, the same from any household (docs/design/settings.md). Saves
# as /account does.
class Settings::ProfilesController < ApplicationController
  include HouseholdScoped

  before_action :set_user

  def show
  end

  def update
    if @user.update(user_params)
      redirect_to household_settings_profile_path, notice: "Your profile is saved."
    else
      render :show, status: :unprocessable_content
    end
  end

  private
    # A copy of the person, so a refused name doesn't show in the sidebar as if it were saved.
    def set_user
      @user = User.find(Current.user.id)
      authorize @user, :update?
    end

    def user_params
      params.expect(user: %i[ name time_zone ])
    end
end
