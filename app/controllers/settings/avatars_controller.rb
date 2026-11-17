# Settings → Profile's Avatar box: the person's own initial color (docs/design/avatars.md, Pages and routes). Always
# Current.user, never a user id from the request.
class Settings::AvatarsController < ApplicationController
  include HouseholdScoped

  def update
    # A copy of the person, so a refused color doesn't show in the sidebar as if it were saved.
    @user = User.find(Current.user.id)
    authorize @user, :update_own?, policy_class: AvatarPolicy

    if @user.change_avatar_color(params.expect(avatar: %i[ color ])[:color])
      redirect_to household_settings_profile_path, notice: "Your avatar is saved."
    else
      render "settings/profiles/show", status: :unprocessable_content
    end
  end
end
