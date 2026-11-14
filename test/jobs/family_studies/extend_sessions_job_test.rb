require "test_helper"

class FamilyStudies::ExtendSessionsJobTest < ActiveJob::TestCase
  setup { @household = households(:home) }

  test "tops up repeating studies only" do
    travel_to Date.new(2026, 11, 14) do
      weekly = study(frequency: "weekly")
      daily_ending_later = study(frequency: "daily", ends_on: Date.new(2026, 11, 20))
      one_off = study(frequency: "once")

      FamilyStudies::ExtendSessionsJob.perform_now

      assert_equal Date.new(2027, 8, 28), weekly.sessions.maximum(:recurrence_at).to_date
      assert_equal 7, daily_ending_later.sessions.count
      assert_empty one_off.sessions
    end
  end

  test "skips ended ones" do
    travel_to Date.new(2026, 11, 14) do
      ended_yesterday = study(frequency: "weekly", starts_on: Date.new(2026, 10, 1), ends_on: Date.new(2026, 11, 13))
      ends_today = study(frequency: "daily", starts_on: Date.new(2026, 10, 1), ends_on: Date.current)

      FamilyStudies::ExtendSessionsJob.perform_now

      assert_empty ended_yesterday.sessions
      assert_empty ends_today.sessions
    end
  end

  test "runs daily in production" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:extend_family_study_sessions)

    assert_equal FamilyStudies::ExtendSessionsJob, task[:class].constantize
    assert_equal "every day", task[:schedule].split(" at ").first
  end

  private
    def study(**attributes)
      @household.family_studies.create!(starts_on: Date.current, time_of_day: "19:00", **attributes)
    end
end
