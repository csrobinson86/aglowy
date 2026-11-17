# Who changes and sees an avatar (docs/design/avatars.md, Who can do what). update_own? is a person's own, from
# Settings → Profile: every active member, children who sign in too. A head or adult setting a child's is update?;
# never reuse one for the other.
class AvatarPolicy < ApplicationPolicy
  def update_own?
    member? && record == membership.user
  end

  # A child's, from Settings → Children: heads and adults of a household the child is an active child in. Never an
  # adult's or a head's (Traps 5).
  def update?
    head_or_adult? && record.memberships.active.child.exists?(household_id: membership.household_id)
  end

  def destroy? = update?

  # The photo is served outside any household, where there's no membership, so this reads Current.user.
  def show_avatar?
    record.visible_to?(Current.user)
  end
end
