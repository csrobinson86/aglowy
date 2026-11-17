# Each household where it's Sunday and the 6 PM hour gets its coming week (docs/design/notifications.md, Recurring jobs).
# Hourly, so every zone has its 6 PM; safe to run twice through the dedupe key.
class Notification::WeeklyPreviewJob < ApplicationJob
  def perform
    Household.at_local_hour(18, wday: 0).find_each { it.send_weekly_preview(it.today.next_day) }
  end
end
