# Mark all as read: any active member, for their own visible notifications only (User#read_all_notifications).
class Notification::ReadingPolicy < ApplicationPolicy
  def create? = member?
end
