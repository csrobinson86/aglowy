# Any active member opens the inbox and their own notifications. Finding them through Current.user.notifications.visible
# does the scoping, so someone else's is a 404 (docs/design/notifications.md, Pages and routes).
class NotificationPolicy < ApplicationPolicy
  def index? = member?
  def show?  = member?
end
