# Deletes briefs more than 60 days old with their writings and chats, daily from config/recurring.yml. They're kept only
# so the next briefs can avoid repeating them (docs/design/daily-brief.md, The purpose).
class DailyBrief::PurgeJob < ApplicationJob
  def perform
    DailyBrief.expired.find_each(&:destroy)
  end
end
