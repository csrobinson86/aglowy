# Sends a notification by email, for those who turned it on (docs/design/notifications.md, Delivery). The inbox needs
# nothing sent. Only throttling is retried: the claim was given back, so the retry sends. Push comes with its own story.
class Notification::DeliveryJob < ApplicationJob
  # Its subject was deleted, taking the notification with it.
  discard_on ActiveJob::DeserializationError
  retry_on Notification::Delivery::Throttled, wait: :polynomially_longer, attempts: 5

  def perform(notification)
    notification.deliver_now
  end
end
