# Sends a notification to the person's phones and browsers and by email, for those who turned them on
# (docs/design/notifications.md, Delivery). The inbox needs nothing sent. Only email throttling is retried: that claim
# was given back, so the retry sends it, and the push claim it finds stops it pushing again.
class Notification::DeliveryJob < ApplicationJob
  # Queued only once the notification commits: the queue is another database, so a worker could otherwise look for it
  # before it's there and discard the job.
  self.enqueue_after_transaction_commit = true
  # A deleted subject takes its notifications with it; ApplicationJob discards their jobs.
  retry_on Notification::Delivery::Throttled, wait: :polynomially_longer, attempts: 5

  def perform(notification)
    notification.deliver_now
  end
end
