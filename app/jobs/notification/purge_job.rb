# Notifications are kept for 90 days; their readings and deliveries go with them (docs/design/notifications.md, Models).
class Notification::PurgeJob < ApplicationJob
  def perform
    Notification.expired.withdraw
  end
end
