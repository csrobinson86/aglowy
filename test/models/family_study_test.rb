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

  test "the first session gets the study's default conductor" do
    study = @household.schedule_family_study(starts_on: "2026-11-17", time_of_day: "19:00", default_conductor: users(:spouse))

    assert_equal users(:spouse), study.sessions.sole.reload.conductor
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

  test "schedule says whether it saved" do
    assert @household.family_studies.new(starts_on: "2026-11-17", time_of_day: "19:00").schedule
    assert_equal false, @household.family_studies.new(starts_on: "2026-11-17", time_of_day: "19:00", frequency: "monthly").schedule
  end

  test "preloaded loads the household" do
    assert FamilyStudy.preloaded.first.association(:household).loaded?
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

  test "session_time_on keeps 7 pm local across a DST change" do
    # DST ends in America/Chicago on Sunday 1 November 2026, so 7 pm moves from 00:00Z to 01:00Z.
    @household.update!(time_zone: "Central Time (US & Canada)")
    study = family_studies(:weekly)

    assert_equal Time.utc(2026, 10, 28, 0), study.session_time_on(Date.new(2026, 10, 27))
    assert_equal Time.utc(2026, 11, 4, 1), study.session_time_on(Date.new(2026, 11, 3))
  end

  test "the horizon on 14 Nov 2026 is 31 Aug 2027" do
    travel_to Date.new(2026, 11, 14) do
      assert_equal Date.new(2027, 8, 31), FamilyStudy.horizon
    end
  end

  test "the horizon on 1 Jul 2027 is 1 Oct 2027" do
    travel_to Date.new(2027, 7, 1) do
      assert_equal Date.new(2027, 10, 1), FamilyStudy.horizon
    end
  end

  test "extending twice creates no duplicates" do
    travel_to Date.new(2026, 11, 14) do
      study = weekly_study_without_sessions

      assert_difference -> { study.sessions.count }, 42 do
        study.extend_sessions
      end
      assert_no_difference -> { study.sessions.count } do
        study.extend_sessions
      end
    end
  end

  test "a moved session (scheduled_at changed) is not recreated" do
    travel_to Date.new(2026, 11, 14) do
      study = @household.schedule_family_study(frequency: "weekly", starts_on: Date.current, time_of_day: "19:00")
      session = study.sessions.find_by!(recurrence_at: study.session_time_on(Date.new(2026, 11, 21)))
      session.update!(scheduled_at: study.session_time_on(Date.new(2026, 11, 22)), detached_at: Time.current)

      assert_no_difference -> { study.sessions.count } do
        study.extend_sessions
      end
      assert_not study.sessions.exists?(scheduled_at: session.recurrence_at)
    end
  end

  test "a cancelled session is not recreated" do
    travel_to Date.new(2026, 11, 14) do
      study = @household.schedule_family_study(frequency: "weekly", starts_on: Date.current, time_of_day: "19:00")
      session = study.sessions.find_by!(recurrence_at: study.session_time_on(Date.new(2026, 11, 21)))
      session.update!(canceled_at: Time.current)

      assert_no_difference -> { study.sessions.count } do
        study.extend_sessions
      end
      assert_equal [ session ], study.sessions.where(scheduled_at: session.scheduled_at).to_a
      assert session.reload.canceled_at
    end
  end

  test "a weekly study created today has sessions through the horizon" do
    travel_to Date.new(2026, 11, 14) do
      study = @household.schedule_family_study(frequency: "weekly", starts_on: Date.current, time_of_day: "19:00", topic: "Ruth")

      expected = Date.new(2026, 11, 14).step(Date.new(2027, 8, 31), 7).map { study.session_time_on(it) }
      sessions = study.sessions.order(:recurrence_at)
      assert_equal expected, sessions.pluck(:recurrence_at)
      assert_equal expected, sessions.pluck(:scheduled_at)
      assert_equal Date.new(2027, 8, 28), sessions.last.recurrence_at.to_date
      assert_equal [ "Ruth" ], sessions.where.not(topic: nil).pluck(:topic)
    end
  end

  test "ends_on stops it" do
    travel_to Date.new(2026, 11, 14) do
      study = @household.schedule_family_study(frequency: "weekly", starts_on: Date.current, ends_on: Date.new(2026, 12, 31), time_of_day: "19:00")

      assert_equal %w[ 2026-11-14 2026-11-21 2026-11-28 2026-12-05 2026-12-12 2026-12-19 2026-12-26 ],
        study.sessions.order(:recurrence_at).map { it.recurrence_at.to_date.iso8601 }
    end
  end

  test "a one-off study is not extended" do
    travel_to Date.new(2026, 11, 14) do
      study = @household.schedule_family_study(starts_on: Date.current, time_of_day: "19:00")

      assert_no_difference -> { study.sessions.count } do
        study.extend_sessions
      end
    end
  end

  test "extended sessions get the default conductor, a UUIDv7 id and timestamps" do
    travel_to Time.utc(2026, 11, 14, 12) do
      study = weekly_study_without_sessions(default_conductor: users(:spouse))
      study.extend_sessions

      session = study.sessions.order(:recurrence_at).last
      assert_equal users(:spouse), session.conductor
      assert_nil session.topic
      assert_equal "7", session.id[14]
      assert_equal Time.current, session.created_at
      assert_equal Time.current, session.updated_at
    end
  end

  test "extending in the household's zone keeps 7 pm local across a DST change" do
    @household.update!(time_zone: "Central Time (US & Canada)")

    travel_to Date.new(2026, 10, 20) do
      study = weekly_study_without_sessions(starts_on: Date.new(2026, 10, 27))
      study.extend_sessions(through: Date.new(2026, 11, 3))

      assert_equal [ Time.utc(2026, 10, 28, 0), Time.utc(2026, 11, 4, 1) ], study.sessions.order(:recurrence_at).pluck(:recurrence_at)
    end
  end

  test "recurrence answers for the study's schedule" do
    assert_equal [ family_studies(:weekly).starts_on + 7 ],
      family_studies(:weekly).recurrence.dates(from: 1.day.ago.to_date, through: 1.day.from_now.to_date)
  end

  test "week_of_month_for counts weeks from the start of the month" do
    study = FamilyStudy.new

    assert_equal 1, study.week_of_month_for(Date.new(2026, 12, 1))
    assert_equal 3, study.week_of_month_for(Date.new(2026, 11, 17))
    assert_equal 4, study.week_of_month_for(Date.new(2026, 11, 28))
    assert_equal 5, study.week_of_month_for(Date.new(2026, 12, 29))
  end

  test "last_week_of_month? is true only for the last such weekday of its month" do
    study = FamilyStudy.new

    assert study.last_week_of_month?(Date.new(2026, 11, 24))
    assert study.last_week_of_month?(Date.new(2026, 12, 29))
    assert_not study.last_week_of_month?(Date.new(2026, 11, 17))
    assert_not study.last_week_of_month?(Date.new(2026, 12, 24))
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

  test "database: a study without a household_id raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_studies(:one_off).update_column(:household_id, nil) }
  end

  test "database: a study without a frequency raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_studies(:one_off).update_column(:frequency, nil) }
  end

  test "database: a study without a interval raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_studies(:one_off).update_column(:interval, nil) }
  end

  test "database: a study without a starts_on raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_studies(:one_off).update_column(:starts_on, nil) }
  end

  test "database: a study without a time_of_day raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_studies(:one_off).update_column(:time_of_day, nil) }
  end

  test "database: a study without a duration_minutes raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_studies(:one_off).update_column(:duration_minutes, nil) }
  end

  test "database: a study for a missing household raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { family_studies(:one_off).update_column(:household_id, SecureRandom.uuid_v7) }
  end

  test "database: a study with a missing default conductor raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { family_studies(:one_off).update_column(:default_conductor_id, SecureRandom.uuid_v7) }
  end

  private
    def weekly_study_without_sessions(**attributes)
      @household.family_studies.create!(frequency: "weekly", starts_on: Date.current, time_of_day: "19:00", **attributes)
    end
end
