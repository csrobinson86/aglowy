require "test_helper"

# A household's own events, in Chicago (docs/design/calendar.md, Household::Event). Occurrences are worked out for
# the range asked for, each built with zone.local from its date (Trap 1).
class Household::EventTest < ActiveSupport::TestCase
  CHICAGO = ActiveSupport::TimeZone["Central Time (US & Canada)"]

  setup do
    @household = households(:parents)
    @household.update!(time_zone: CHICAGO.name)
  end

  test "the database refuses a timed event lasting 3 days" do
    assert_raises(ActiveRecord::CheckViolation) do
      Household::Event.insert!(row(time_of_day: "19:00", duration_minutes: 60, days: 3))
    end
  end

  test "the database refuses a timed event without a duration" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(time_of_day: "19:00")) }
  end

  test "the database refuses a monthly event without a week of the month" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(frequency: "monthly")) }
  end

  test "the database refuses an event of 15 days" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(days: 15)) }
  end

  test "the database refuses a repeating event of several days" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(days: 2, frequency: "weekly")) }
  end

  test "the database refuses an unknown kind" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(kind: "party")) }
  end

  test "the database refuses a title over 80 characters" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(title: "x" * 81)) }
  end

  test "the database refuses a duration over 12 hours" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(time_of_day: "08:00", duration_minutes: 721)) }
  end

  test "the database refuses a duration of 0" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(time_of_day: "08:00", duration_minutes: 0)) }
  end

  test "the database refuses an unknown frequency" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(frequency: "daily")) }
  end

  test "the database refuses an interval of 0" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(interval: 0)) }
  end

  test "the database refuses a sixth week of the month" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(frequency: "monthly", week_of_month: 6)) }
  end

  test "the database refuses a location over 120 characters" do
    assert_raises(ActiveRecord::CheckViolation) { Household::Event.insert!(row(location: "x" * 121)) }
  end

  test "validations match the checks" do
    event = event(kind: "party", title: "", days: 3, time_of_day: "19:00", frequency: "monthly", location: "x" * 121, note: "x" * 501)

    assert_not event.valid?
    # A time with no duration has no end, so Ends is blank too.
    assert_equal %i[ days duration_minutes ends_at kind location note title week_of_month ], event.errors.attribute_names.sort
  end

  test "the note is encrypted" do
    event = event(note: "Bring lunch").tap(&:save!)

    assert_equal "Bring lunch", event.reload.note
    assert_not_includes Household::Event.connection.select_value(Household::Event.where(id: event).select(:note).to_sql), "Bring lunch"
  end

  test "a weekly event's occurrences in a month" do
    service = event(kind: "field_service", starts_on: Date.new(2026, 11, 7), time_of_day: "09:30", duration_minutes: 90, frequency: "weekly")

    assert_equal [ 7, 14, 21, 28 ].map { CHICAGO.local(2026, 11, it, 9, 30)...CHICAGO.local(2026, 11, it, 11) },
                 service.occurrences_between(Date.new(2026, 11, 1)..Date.new(2026, 11, 30))
  end

  test "a monthly event on the fifth Saturday skips a month without one" do
    cleaning = event(starts_on: Date.new(2026, 10, 31), time_of_day: "13:00", duration_minutes: 120, frequency: "monthly", week_of_month: 5)

    assert_equal [ CHICAGO.local(2026, 10, 31, 13), CHICAGO.local(2027, 1, 30, 13) ],
                 cleaning.occurrences_between(Date.new(2026, 10, 1)..Date.new(2027, 1, 31)).map(&:begin)
  end

  test "a 6-day event is one occurrence from its first day to its last" do
    visit = event(kind: "co_visit", starts_on: Date.new(2026, 11, 17), days: 6)
    whole_visit = CHICAGO.local(2026, 11, 17)...CHICAGO.local(2026, 11, 23)

    assert_equal [ whole_visit ], visit.occurrences_between(Date.new(2026, 11, 16)..Date.new(2026, 11, 22))
    assert_equal [ whole_visit ], visit.occurrences_between(Date.new(2026, 11, 22)..Date.new(2026, 11, 28))
    assert_empty visit.occurrences_between(Date.new(2026, 11, 23)..Date.new(2026, 11, 29))
  end

  test "a 7:00 PM event in the week daylight saving time ends stays at 7:00 PM" do
    weekly = event(starts_on: Date.new(2026, 10, 29), time_of_day: "19:00", duration_minutes: 60, frequency: "weekly")

    starts = weekly.occurrences_between(Date.new(2026, 10, 26)..Date.new(2026, 11, 8)).map(&:begin)

    assert_equal [ CHICAGO.local(2026, 10, 29, 19), CHICAGO.local(2026, 11, 5, 19) ], starts
    assert_equal [ 19, 19 ], starts.map { it.in_time_zone(CHICAGO).hour }
    assert_equal [ 0, 1 ], starts.map { it.utc.hour }
  end

  test "repeats_until ends a weekly event" do
    weekly = event(starts_on: Date.new(2026, 11, 7), frequency: "weekly", repeats_until: Date.new(2026, 11, 14))

    assert_equal 2, weekly.occurrences_between(Date.new(2026, 11, 1)..Date.new(2026, 11, 30)).size
  end

  test "schedule saves an all-day event of several days from the dialog's Starts and Ends" do
    event = @household.events.new(created_by: users(:grandparent))

    assert event.schedule(kind: "co_visit", title: "Circuit overseer's visit", all_day: "1", starts_on: "2026-11-17", ends_on: "2026-11-22",
                          starts_at: "19:00", ends_at: "20:00", repeat: "weekly")
    assert_equal [ 6, nil, nil, "once" ], [ event.days, event.time_of_day, event.duration_minutes, event.frequency ]
  end

  test "schedule saves a timed event from the dialog's Date, Starts and Ends, monthly on the last Saturday" do
    event = @household.events.new(created_by: users(:grandparent))

    assert event.schedule(kind: "other", title: "Kingdom Hall cleaning", all_day: "0", starts_on: "2026-11-28", ends_on: "2026-12-02",
                          starts_at: "13:00", ends_at: "15:30", repeat: "monthly_last")
    assert_equal [ 1, "13:00", 150, "monthly", -1 ], [ event.days, event.time_of_day.strftime("%H:%M"), event.duration_minutes, event.frequency, event.week_of_month ]
    assert_equal [ "13:00", "15:30", "monthly_last", false ], [ event.reload.starts_at.strftime("%H:%M"), event.ends_at.strftime("%H:%M"), event.repeat, event.all_day ]
  end

  test "schedule saves monthly on the date's week of the month" do
    event = @household.events.new(created_by: users(:grandparent))

    assert event.schedule(kind: "field_service", title: "Field service", all_day: "0", starts_on: "2026-11-21", starts_at: "09:30", ends_at: "11:00", repeat: "monthly")
    assert_equal [ "monthly", 3, "monthly" ], [ event.frequency, event.week_of_month, event.reload.repeat ]
  end

  test "schedule refuses Ends before Starts, and an all-day Ends before its first day" do
    timed = @household.events.new(created_by: users(:grandparent))
    assert_not timed.schedule(kind: "other", title: "Cleaning", all_day: "0", starts_on: "2026-11-28", starts_at: "13:00", ends_at: "12:00", repeat: "once")
    assert_equal [ "must be after Starts" ], timed.errors[:ends_at]

    all_day = @household.events.new(created_by: users(:grandparent))
    assert_not all_day.schedule(kind: "memorial", title: "Memorial", all_day: "1", starts_on: "2026-11-28", ends_on: "2026-11-27", repeat: "once")
    assert_equal [ "can't be before Starts" ], all_day.errors[:ends_on]
  end

  test "schedule refuses Starts, Ends or an all-day Ends sent blank or unreadable, on a new event and a saved one" do
    timed = @household.events.new(created_by: users(:grandparent))
    assert_not timed.schedule(kind: "other", title: "Cleaning", all_day: "0", starts_on: "2026-11-28", starts_at: "", ends_at: "15:00", repeat: "once")
    assert_equal [ "can't be blank" ], timed.errors[:starts_at]

    saved = event(time_of_day: "09:00", duration_minutes: 60).tap(&:save!)
    assert_not saved.schedule(all_day: "0", starts_on: "2026-11-21", starts_at: "09:00", ends_at: "", repeat: "once")
    assert_equal [ "can't be blank" ], saved.errors[:ends_at]
    assert_not saved.reload.schedule(all_day: "0", starts_on: "2026-11-21", starts_at: "nine", ends_at: "10:00", repeat: "once")
    assert_equal [ "can't be blank" ], saved.errors[:starts_at]

    visit = event(kind: "co_visit", starts_on: Date.new(2026, 11, 17), days: 6).tap(&:save!)
    assert_not visit.schedule(all_day: "1", starts_on: "2026-11-17", ends_on: "", repeat: "once")
    assert_equal [ "can't be blank" ], visit.errors[:ends_on]
    assert_equal [ "09:00", 60, 6 ], [ saved.reload.time_of_day.strftime("%H:%M"), saved.duration_minutes, visit.reload.days ]
  end

  test "schedule refuses a Repeats choice the date doesn't offer" do
    event = @household.events.new(created_by: users(:grandparent))

    assert_not event.schedule(kind: "other", title: "Cleaning", all_day: "0", starts_on: "2026-11-21", starts_at: "13:00", ends_at: "15:00", repeat: "monthly_last")
    assert_equal [ "isn't offered for that date" ], event.errors[:repeat]
  end

  test "the dialog's times stay wall-clock times whatever the request's zone" do
    event = @household.events.new(created_by: users(:grandparent))

    Time.use_zone("Tokyo") do
      assert event.schedule(kind: "other", title: "Cleaning", all_day: "0", starts_on: "2026-11-21", starts_at: "09:30", ends_at: "11:00", repeat: "once")
    end
    assert_equal [ "09:30", 90 ], [ event.reload.time_of_day.strftime("%H:%M"), event.duration_minutes ]
  end

  test "repeat_choices come from the date, with the last only on the last" do
    assert_equal [ [ "Doesn't repeat", "once" ], [ "Weekly on Saturday", "weekly" ], [ "Monthly on the fourth Saturday", "monthly" ],
                   [ "Monthly on the last Saturday", "monthly_last" ] ], event(starts_on: Date.new(2026, 11, 28)).repeat_choices
    assert_equal [ [ "Doesn't repeat", "once" ], [ "Weekly on Saturday", "weekly" ], [ "Monthly on the third Saturday", "monthly" ] ],
                 event(starts_on: Date.new(2026, 11, 21)).repeat_choices
  end

  private
    def event(**attributes)
      @household.events.new(kind: "other", title: "Kingdom Hall cleaning", starts_on: Date.new(2026, 11, 21), created_by: users(:grandparent), **attributes)
    end

    def row(**attributes)
      { household_id: @household.id, kind: "other", title: "Kingdom Hall cleaning", starts_on: "2026-11-21", created_by_id: users(:grandparent).id, **attributes }
    end
end
