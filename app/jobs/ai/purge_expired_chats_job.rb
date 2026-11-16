# Deletes AI chats and their messages after 7 days, daily from config/recurring.yml (docs/design/ai.md, safety
# measure 10).
class Ai::PurgeExpiredChatsJob < ApplicationJob
  def perform
    Chat.expired.find_each(&:destroy)
  end
end
