# Deletes listening games more than 8 weeks old, with their rounds, cards and sources, daily from config/recurring.yml
# (docs/design/listening-game.md, Models). A child's finds keep their own labels, so her notes read the same.
class ListeningGame::PurgeJob < ApplicationJob
  def perform
    ListeningGame.expired.delete_all
  end
end
