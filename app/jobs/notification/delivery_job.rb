# Sends a notification by email and push, for those who turned them on (docs/design/notifications.md, Delivery). The
# inbox needs nothing sent, so until email and push arrive in later NOTIFY-01 stories, it does nothing.
class Notification::DeliveryJob < ApplicationJob
  # Its subject was deleted, taking the notification with it.
  discard_on ActiveJob::DeserializationError

  def perform(notification)
  end
end
