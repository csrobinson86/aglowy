# Mark all as read, from the inbox: every visible unread notification the person has (docs/design/notifications.md).
class Notifications::ReadingsController < ApplicationController
  include HouseholdScoped

  def create
    authorize Notification::Reading
    Current.user.read_all_notifications
    redirect_to household_notifications_path, status: :see_other
  end
end
