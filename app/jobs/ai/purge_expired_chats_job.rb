# Deletes AI chats and their messages after 7 days, daily from config/recurring.yml (docs/design/ai.md, safety
# measure 10). One that can't be deleted is reported and the rest still go.
class Ai::PurgeExpiredChatsJob < ApplicationJob
  def perform
    each_reporting_failures(Chat.expired, &:destroy)
  end
end
