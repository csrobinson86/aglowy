require "test_helper"

# Games are kept for 8 weeks (docs/design/listening-game.md, Models). A child's finds keep their own labels, so they stay
# when a game goes; they arrive with #341.
class ListeningGame::PurgeJobTest < ActiveJob::TestCase
  THIS_WEEK = Date.new(2026, 11, 16)

  test "a game more than 8 weeks old goes with its rounds and cards, and an 8-week-old one stays" do
    old = ListeningGame.create!(household: households(:home), week_of: THIS_WEEK - 9.weeks)
    round = old.rounds.create!(step: "talk", position: 1)
    kept = ListeningGame.create!(household: households(:home), week_of: THIS_WEEK - 8.weeks)

    # Sunday, the last day of the week, so the 8-week-old game is at its oldest.
    travel_to(Time.utc(2026, 11, 22, 4, 45)) { ListeningGame::PurgeJob.perform_now }

    assert_not ListeningGame.exists?(old.id)
    assert_not ListeningGame::Round.exists?(round.id)
    assert ListeningGame.exists?(kept.id)
    assert ListeningGame.exists?(listening_games(:home_nov_9).id)
  end

  test "it runs every day at 4:45am in production" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:purge_old_listening_games)

    assert_equal "ListeningGame::PurgeJob", task[:class]
    assert_equal "every day at 4:45am", task[:schedule]
  end
end
