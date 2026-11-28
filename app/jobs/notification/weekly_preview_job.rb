# Each household where it's Sunday and the 6 PM hour gets its coming week (docs/design/notifications.md, Recurring jobs).
# Hourly, so every zone has its 6 PM; safe to run twice through the dedupe key. One that fails is reported and the rest
# go on.
class Notification::WeeklyPreviewJob < ApplicationJob
  def perform
    each_reporting_failures(Household.at_local_hour(18, wday: 0)) { it.send_weekly_preview(it.today.next_day) }
  end
end
