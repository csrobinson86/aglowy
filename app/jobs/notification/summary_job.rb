# One person's daily summary for the quiet-hours end they were due for (docs/design/notifications.md, Delivery, step 3).
# A retry carries its own through and never asks whether the person is still due. Only throttling is retried.
class Notification::SummaryJob < ApplicationJob
  discard_on ActiveJob::DeserializationError
  retry_on Notification::Delivery::Throttled, wait: :polynomially_longer, attempts: 5

  def perform(user, through)
    user.send_daily_summary_now(through:)
  end
end
