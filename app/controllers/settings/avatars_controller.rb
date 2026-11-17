# Settings → Profile's Avatar box: the person's own photo and initial color (docs/design/avatars.md, Pages and routes).
# Always Current.user, never a user id from the request.
class Settings::AvatarsController < ApplicationController
  include HouseholdScoped

  before_action :set_user

  # avatar[photo] from the preview dialog, or avatar[color] from the color picker.
  def update
    avatar = params.expect(avatar: %i[ photo color ])

    if avatar.key?(:photo) ? @user.change_avatar(avatar[:photo]) : @user.change_avatar_color(avatar[:color])
      redirect_to household_settings_profile_path, notice: "Your avatar is saved."
    else
      render "settings/profiles/show", status: :unprocessable_content
    end
  end

  def destroy
    @user.remove_avatar
    redirect_to household_settings_profile_path, notice: "Your photo is removed."
  end

  private
    # A copy of the person, so a refused change doesn't show in the sidebar as if it were saved.
    def set_user
      @user = User.find(Current.user.id)
      authorize @user, :update_own?, policy_class: AvatarPolicy
    end
end
