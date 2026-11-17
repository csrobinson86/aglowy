# Any active member, children too, turns push on and removes their own devices. Finding them through
# Current.user.push_subscriptions does the scoping, so someone else's is a 404 (docs/design/notifications.md).
class PushSubscriptionPolicy < ApplicationPolicy
  def create?  = member?
  def destroy? = member?
end
