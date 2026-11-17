# Who changes and sees an avatar (docs/design/avatars.md, Who can do what). update_own? is a person's own, from
# Settings → Profile: every active member, children who sign in too. A head or adult setting a child's is a separate
# rule; never reuse one for the other.
class AvatarPolicy < ApplicationPolicy
  def update_own?
    member? && record == membership.user
  end

  # The photo is served outside any household, where there's no membership, so this reads Current.user.
  def show_avatar?
    record.visible_to?(Current.user)
  end
end
