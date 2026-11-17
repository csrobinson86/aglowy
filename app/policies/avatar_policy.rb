# Who changes an avatar (docs/design/avatars.md, Who can do what). update_own? is a person's own, from Settings →
# Profile: every active member, children who sign in too. A head or adult setting a child's is a separate rule; never
# reuse one for the other.
class AvatarPolicy < ApplicationPolicy
  def update_own?
    member? && record == membership.user
  end
end
