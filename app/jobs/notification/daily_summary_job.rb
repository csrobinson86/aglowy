# Every 15 minutes: each person with a summary kind's email on who is due a summary and not in quiet hours gets a job
# for the quiet-hours end they're due for (docs/design/notifications.md, Delivery, step 3). Safe to run twice: two
# jobs for one end gather the same notifications, and the claims leave one summary.
class Notification::DailySummaryJob < ApplicationJob
  def perform
    User.getting_summary_email.find_each do |user|
      through = user.summary_due_through
      user.send_daily_summary_later(through:) if through
    end
  end
end
