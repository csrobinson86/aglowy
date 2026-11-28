# Deletes briefs more than 60 days old with their writings and chats, daily from config/recurring.yml. They're kept only
# so the next briefs can avoid repeating them (docs/design/daily-brief.md, The purpose). One that can't be deleted is
# reported and the rest still go.
class DailyBrief::PurgeJob < ApplicationJob
  def perform
    each_reporting_failures(DailyBrief.expired, &:destroy)
  end
end
