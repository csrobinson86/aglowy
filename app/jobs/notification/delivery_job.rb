# Sends a notification to the person's phones and browsers and by email, for those who turned them on
# (docs/design/notifications.md, Delivery). The inbox needs nothing sent. Only email throttling is retried: that claim
# was given back, so the retry sends it, and the push claim it finds stops it pushing again.
class Notification::DeliveryJob < ApplicationJob
  # Its subject was deleted, taking the notification with it.
  discard_on ActiveJob::DeserializationError
  retry_on Notification::Delivery::Throttled, wait: :polynomially_longer, attempts: 5

  def perform(notification)
    notification.deliver_now
  end
end
