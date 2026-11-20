require "test_helper"

# Get ready weeks are kept for 8 weeks (docs/design/meeting-prep.md, PrepWeek). Her comments and drawings are on her
# meeting notes, so nothing of hers goes with them.
class PrepWeek::PurgeJobTest < ActiveJob::TestCase
  THIS_WEEK = Date.new(2026, 11, 16)

  test "weeks older than 8 weeks go with their cards; newer stay" do
    old = PrepWeek.create!(household: households(:home), week_of: THIS_WEEK - 9.weeks)
    card = prep_card(old, "talk")
    kept = PrepWeek.create!(household: households(:home), week_of: THIS_WEEK - 8.weeks)

    # Sunday, the last day of the week, so the 8-week-old one is at its oldest.
    travel_to(Time.utc(2026, 11, 22, 4, 50)) { PrepWeek::PurgeJob.perform_now }

    assert_not PrepWeek.exists?(old.id)
    assert_not PrepWeek::Card.exists?(card.id)
    assert PrepWeek.exists?(kept.id)
    assert PrepWeek.exists?(prep_weeks(:home_nov_9).id)
  end

  test "it runs every day at 4:50am in production" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:purge_old_prep_weeks)

    assert_equal "PrepWeek::PurgeJob", task[:class]
    assert_equal "every day at 4:50am", task[:schedule]
  end
end
