# Settings → Children → "Children's avatars": a head or adult sets a child's photo or initial color, so a child without
# a login gets one too (docs/design/avatars.md, Children's avatars). The child is found through this household's active
# child seats, so an adult here, or a child elsewhere, is a 404.
class Settings::Children::AvatarsController < ApplicationController
  include HouseholdScoped

  before_action :set_child

  # avatar[photo] from the preview dialog, or avatar[color] from the color picker, as in Settings::AvatarsController.
  def update
    avatar = params.expect(avatar: %i[ photo color ])

    if avatar.key?(:photo) ? @child.change_avatar(avatar[:photo]) : @child.change_avatar_color(avatar[:color])
      redirect_to household_settings_children_path, notice: "#{@child.first_name}'s avatar is saved."
    else
      # As Settings::ChildrenController; the rows show the children as saved, and the refusal on this child's row.
      @children = Current.household.memberships.active.child.preloaded.includes(study_ai_grant: :granted_by).by_role
      render "settings/children/show", status: :unprocessable_content
    end
  end

  def destroy
    @child.remove_avatar
    redirect_to household_settings_children_path, notice: "#{@child.first_name}'s photo is removed."
  end

  private
    def set_child
      @child = Current.household.memberships.active.child.find_by!(user_id: params[:child_id]).user
      authorize @child, policy_class: AvatarPolicy
    end
end
