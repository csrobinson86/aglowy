require "test_helper"

class FamilyStudy::SchedulingTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 11, 14, 18)
    @household = households(:home)
  end

  test "one-off → one session" do
    scheduling = new_scheduling(repeat: "once", topic: "Imitate Their Faith")

    assert_difference -> { FamilyStudy.count } => 1, -> { FamilyStudy::Session.count } => 1 do
      assert scheduling.save
    end

    study = scheduling.study
    assert_equal @household, study.household
    assert study.once?
    assert_equal Date.new(2026, 11, 17), study.starts_on
    assert_equal "19:00", study.time_of_day.strftime("%H:%M")
    assert_equal 45, study.duration_minutes
    assert_equal "Imitate Their Faith", study.sessions.sole.topic
  end

  test "weekly → sessions through the horizon" do
    scheduling = new_scheduling(repeat: "weekly")
    assert scheduling.save

    study = scheduling.study
    assert study.weekly?
    sessions = study.sessions.order(:scheduled_at)
    assert_equal study.session_time_on(Date.new(2026, 11, 17)), sessions.first.scheduled_at
    assert_equal study.session_time_on(Date.new(2027, 8, 31)), sessions.last.scheduled_at
    assert_equal 42, sessions.count
    assert_equal [ nil ], sessions.excluding(sessions.first).pluck(:topic).uniq, "later sessions start with no topic"
  end

  test "daily repeats every day" do
    scheduling = new_scheduling(repeat: "daily")
    assert scheduling.save

    assert scheduling.study.daily?
  end

  test "monthly on the third Tuesday sets week_of_month = 3" do
    scheduling = new_scheduling(repeat: "monthly")
    assert scheduling.save

    study = scheduling.study
    assert study.monthly?
    assert_equal 3, study.week_of_month
  end

  test "\"monthly on the last Tuesday\" sets week_of_month = -1" do
    scheduling = new_scheduling(starts_on: "2026-11-24", repeat: "monthly_last")
    assert scheduling.save

    study = scheduling.study
    assert study.monthly?
    assert_equal(-1, study.week_of_month)
  end

  test "the choices for 17 Nov 2026 have no \"last\" option" do
    assert_equal [
      [ "Does not repeat", "once" ],
      [ "Daily", "daily" ],
      [ "Weekly on Tuesday", "weekly" ],
      [ "Monthly on the third Tuesday", "monthly" ]
    ], new_scheduling.repeat_choices
  end

  test "the choices for 24 Nov 2026 do" do
    assert_equal [
      [ "Does not repeat", "once" ],
      [ "Daily", "daily" ],
      [ "Weekly on Tuesday", "weekly" ],
      [ "Monthly on the fourth Tuesday", "monthly" ],
      [ "Monthly on the last Tuesday", "monthly_last" ]
    ], new_scheduling(starts_on: "2026-11-24").repeat_choices
  end

  test "a fifth weekday is offered as both fifth and last" do
    labels = new_scheduling(starts_on: "2026-12-29").repeat_choices.map(&:first)

    assert_includes labels, "Monthly on the fifth Tuesday"
    assert_includes labels, "Monthly on the last Tuesday"
  end

  test "without a date, only the choices that don't need one" do
    assert_equal [ [ "Does not repeat", "once" ], [ "Daily", "daily" ] ], new_scheduling(starts_on: "").repeat_choices
  end

  test "Ends before Starts is an error on Ends" do
    scheduling = new_scheduling(starts_at: "19:00", ends_at: "18:30")

    assert_no_difference [ "FamilyStudy.count", "FamilyStudy::Session.count" ] do
      assert_not scheduling.save
    end
    assert_equal [ "must be after Starts. Studies that end after midnight aren't supported." ], scheduling.errors[:ends_at]
    assert_empty scheduling.errors[:starts_at]
  end

  test "Ends equal to Starts is an error on Ends" do
    assert_not_empty new_scheduling(ends_at: "19:00").tap(&:validate).errors[:ends_at]
  end

  test "Ends less than a minute after Starts is an error on Ends" do
    assert_not_empty new_scheduling(starts_at: "19:00:00", ends_at: "19:00:40").tap(&:validate).errors[:ends_at]
  end

  test "a date in the past is an error, judged in the household's zone" do
    # 6 pm on 14 Nov in UTC is already 15 Nov in Tokyo.
    @household.update!(time_zone: "Tokyo")

    assert_equal [ "can't be in the past" ], new_scheduling(starts_on: "2026-11-14").tap(&:validate).errors[:starts_on]
    assert new_scheduling(starts_on: "2026-11-15").valid?
  end

  test "today is allowed" do
    assert new_scheduling(starts_on: "2026-11-14").valid?
  end

  test "Date, Starts and Ends are required" do
    scheduling = FamilyStudy::Scheduling.new(household: @household, starts_on: "")

    assert_not scheduling.valid?
    assert_includes scheduling.errors[:starts_on], "can't be blank"
    assert_includes scheduling.errors[:starts_at], "can't be blank"
    assert_includes scheduling.errors[:ends_at], "can't be blank"
  end

  test "a repeat that the date doesn't offer is an error" do
    scheduling = new_scheduling(repeat: "monthly_last")

    assert_not scheduling.save
    assert_equal [ "is not included in the list" ], scheduling.errors[:repeat]
  end

  test "the topic is optional, and a blank one is stored as none" do
    scheduling = new_scheduling(topic: "  ")
    assert scheduling.save

    assert_nil scheduling.study.sessions.sole.topic
  end

  test "Does not repeat is the default" do
    assert_equal "once", FamilyStudy::Scheduling.new(household: @household).repeat
  end

  test "the date defaults to today in the household's zone" do
    @household.update!(time_zone: "Tokyo")

    assert_equal Date.new(2026, 11, 15), FamilyStudy::Scheduling.new(household: @household).starts_on
  end

  private
    def new_scheduling(**attributes)
      FamilyStudy::Scheduling.new(household: @household, topic: "Proverbs 3", starts_on: "2026-11-17",
                                  starts_at: "19:00", ends_at: "19:45", repeat: "once", **attributes)
    end
end
