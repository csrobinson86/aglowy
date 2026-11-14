require "test_helper"

class FamilyStudyTest < ActiveSupport::TestCase
  setup { @household = households(:home) }

  test "creating a study creates exactly one session" do
    assert_difference -> { FamilyStudy.count } => 1, -> { FamilyStudy::Session.count } => 1 do
      @study = @household.schedule_family_study(starts_on: "2026-11-17", time_of_day: "19:00", topic: "Imitate Their Faith")
    end

    session = @study.sessions.sole
    assert_equal "Imitate Their Faith", session.topic
    assert_equal @study.first_session_at, session.recurrence_at
    assert_equal @study.first_session_at, session.scheduled_at
  end

  test "the topic is optional" do
    study = @household.schedule_family_study(starts_on: "2026-11-17", time_of_day: "19:00")

    assert_nil study.sessions.sole.topic
  end

  test "an invalid study creates no session" do
    assert_no_difference [ "FamilyStudy.count", "FamilyStudy::Session.count" ] do
      study = @household.schedule_family_study(starts_on: "2026-11-17", time_of_day: "19:00", frequency: "monthly")

      assert_not study.persisted?
    end
  end

  test "the session's time is 7 pm local in the household's zone, stored as UTC" do
    @household.update!(time_zone: "Pacific Time (US & Canada)")

    session = @household.schedule_family_study(starts_on: "2026-11-17", time_of_day: "19:00").sessions.sole.reload

    assert_equal "19:00", session.scheduled_at.in_time_zone(@household.time_zone).strftime("%H:%M")
    stored = FamilyStudy::Session.where(id: session.id).select("scheduled_at::text AS scheduled, recurrence_at::text AS recurrence")
    assert_equal [ [ "2026-11-18 03:00:00", "2026-11-18 03:00:00" ] ], FamilyStudy::Session.connection.select_rows(stored.to_sql)
  end

  test "a 7 pm study in America/Chicago is 7 pm local on both sides of the November DST change" do
    # Rails names America/Chicago "Central Time (US & Canada)"; DST ends there on Sunday 1 November 2026.
    @household.update!(time_zone: "Central Time (US & Canada)")

    before = @household.schedule_family_study(starts_on: "2026-10-31", time_of_day: "19:00").sessions.sole.reload
    after  = @household.schedule_family_study(starts_on: "2026-11-01", time_of_day: "19:00").sessions.sole.reload

    assert_equal Time.utc(2026, 11, 1, 0), before.scheduled_at
    assert_equal Time.utc(2026, 11, 2, 1), after.scheduled_at
    [ before, after ].each do |session|
      assert_equal 19, session.scheduled_at.in_time_zone("America/Chicago").hour
    end
  end

  test "time_of_day keeps its wall-clock value whatever the process time zone" do
    @household.update!(time_zone: "Central Time (US & Canada)")
    study = Time.use_zone("Tokyo") { @household.schedule_family_study(starts_on: "2026-11-17", time_of_day: "19:00") }

    assert_equal Time.utc(2026, 11, 18, 1), study.reload.first_session_at
  end

  test "monthly without week_of_month is invalid" do
    study = @household.family_studies.new(frequency: "monthly", starts_on: "2026-11-17", time_of_day: "19:00")

    assert_not study.valid?
    assert_includes study.errors[:week_of_month], "can't be blank"
  end

  test "monthly on the last Tuesday is valid" do
    assert @household.family_studies.new(frequency: "monthly", week_of_month: -1, starts_on: "2026-11-24", time_of_day: "19:00").valid?
  end

  test "an unknown frequency, a zero interval or duration and week_of_month 6 are validation errors" do
    study = @household.family_studies.new(frequency: "yearly", interval: 0, duration_minutes: 0, week_of_month: 6)

    assert_not study.valid?
    assert_includes study.errors[:frequency], "is not included in the list"
    assert_includes study.errors[:interval], "must be greater than 0"
    assert_includes study.errors[:duration_minutes], "must be greater than 0"
    assert_includes study.errors[:week_of_month], "is not included in the list"
    assert_includes study.errors[:starts_on], "can't be blank"
    assert_includes study.errors[:time_of_day], "can't be blank"
  end

  test "defaults to a one-off hour-long study" do
    study = FamilyStudy.new

    assert study.once?
    assert_equal 1, study.interval
    assert_equal 60, study.duration_minutes
  end

  test "destroying a household destroys its studies and their sessions" do
    assert_difference -> { FamilyStudy.count } => -2, -> { FamilyStudy::Session.count } => -5 do
      @household.destroy!
    end
  end

  test "database: frequency outside the list raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { family_studies(:one_off).update_column(:frequency, "yearly") }
  end

  test "database: interval 0 raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { family_studies(:one_off).update_column(:interval, 0) }
  end

  test "database: duration 0 raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { family_studies(:one_off).update_column(:duration_minutes, 0) }
  end

  test "database: monthly without week_of_month raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { family_studies(:one_off).update_column(:frequency, "monthly") }
  end

  test "database: week_of_month 6 raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { family_studies(:one_off).update_column(:week_of_month, 6) }
  end

  test "database: a study without a time_of_day raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_studies(:one_off).update_column(:time_of_day, nil) }
  end

  test "database: a study for a missing household raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { family_studies(:one_off).update_column(:household_id, SecureRandom.uuid_v7) }
  end
end
