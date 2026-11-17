require "test_helper"

# A person's own times on the calendar (docs/design/calendar.md, PersonalTime). Tuesday 17 November 2026; Sam Spouse's
# profile zone is Chicago.
class PersonalTimeTest < ActiveSupport::TestCase
  CHICAGO = ActiveSupport::TimeZone["Central Time (US & Canada)"]
  EASTERN = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  PACIFIC = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
  WEEK = CHICAGO.local(2026, 11, 16)...CHICAGO.local(2026, 11, 23)
  EVERY_DAY = [ 0, 1, 2, 3, 4, 5, 6 ].freeze

  setup do
    travel_to Time.utc(2026, 11, 17, 18)
    @user = users(:spouse)
    @user.update!(time_zone: CHICAGO.name)
  end

  test "the database refuses wdays of {}" do
    assert_raises(ActiveRecord::CheckViolation) { PersonalTime.insert!(row(wdays: [])) }
  end

  test "the database refuses wdays of {7}" do
    assert_raises(ActiveRecord::CheckViolation) { PersonalTime.insert!(row(wdays: [ 7 ])) }
  end

  test "the database refuses a duration outside 5 to 240 minutes" do
    assert_raises(ActiveRecord::CheckViolation) { PersonalTime.insert!(row(duration_minutes: 241)) }
  end

  test "the database refuses an opens_type that isn't a study or a note" do
    assert_raises(ActiveRecord::CheckViolation) { PersonalTime.insert!(row(opens_type: "Household", opens_id: households(:home).id)) }
  end

  test "the database refuses an opens_type without an opens_id" do
    assert_raises(ActiveRecord::CheckViolation) { PersonalTime.insert!(row(opens_type: "PersonalStudy")) }
  end

  test "occurrences on its weekdays in a week, with their done state" do
    time = personal_time(wdays: [ 2, 4 ], time_of_day: "18:00")
    time.complete(on: Date.new(2026, 11, 17))

    occurrences = @user.personal_times.occurring_between(WEEK)

    assert_equal [ CHICAGO.local(2026, 11, 17, 18), CHICAGO.local(2026, 11, 19, 18) ], occurrences.map(&:starts_at)
    assert_equal [ Date.new(2026, 11, 17), Date.new(2026, 11, 19) ], occurrences.map(&:on)
    assert_equal [ true, false ], occurrences.map(&:done?)
    assert_equal [ false, true ], occurrences.map(&:future?)
    assert_equal CHICAGO.local(2026, 11, 17, 18, 30), occurrences.first.ends_at
  end

  test "nothing before the day it starts" do
    personal_time(starts_on: Date.new(2026, 11, 19))

    assert_equal [ 19, 20, 21, 22 ], @user.personal_times.occurring_between(WEEK).map { it.on.day }
  end

  test "6:30 AM stays 6:30 AM across a DST change" do
    personal_time(wdays: [ 1 ])

    occurrences = @user.personal_times.occurring_between(CHICAGO.local(2026, 10, 26)...CHICAGO.local(2026, 11, 9))

    assert_equal [ "06:30", "06:30" ], occurrences.map { it.starts_at.in_time_zone(CHICAGO).strftime("%H:%M") }
    assert_equal [ 11, 12 ], occurrences.map { it.starts_at.utc.hour }
  end

  test "a person in another zone than the household shows at the converted time" do
    @user.update!(time_zone: EASTERN.name)
    households(:home).update!(time_zone: CHICAGO.name)
    personal_time(wdays: [ 2 ])

    item = Household::Calendar.new(households(:home), viewer: @user, range: WEEK.begin.to_date..Date.new(2026, 11, 22)).items.select(&:my_time?).sole

    assert_equal [ "my_time", "Daily Bible reading" ], [ item.kind, item.title ]
    assert_equal CHICAGO.local(2026, 11, 17, 5, 30), item.starts_at
    assert_equal CHICAGO, item.starts_at.time_zone
  end

  test "a 12:30 AM Monday time in Tokyo lands in the Los Angeles week before, on Sunday afternoon" do
    @user.update!(time_zone: "Tokyo")
    personal_time(wdays: [ 1 ], time_of_day: "00:30")

    occurrences = @user.personal_times.occurring_between(PACIFIC.local(2026, 11, 16)...PACIFIC.local(2026, 11, 23))

    assert_equal [ PACIFIC.local(2026, 11, 22, 7, 30) ], occurrences.map(&:starts_at)
    assert_equal Date.new(2026, 11, 23), occurrences.sole.on
  end

  test "with users.time_zone blank, calendar_time_zone is the first active household's by name; with no household, UTC" do
    households(:parents).update!(time_zone: CHICAGO.name)
    households(:home).update!(time_zone: EASTERN.name)

    assert_nil users(:head).time_zone
    assert_equal CHICAGO.name, users(:head).calendar_time_zone
    assert_equal "UTC", users(:former).calendar_time_zone
    assert_equal "UTC", users(:newcomer).calendar_time_zone
    assert_equal CHICAGO.name, @user.calendar_time_zone
  end

  test "creating the first time with a blank profile zone saves the household's zone; a later household rename doesn't move the time" do
    households(:parents).update!(time_zone: CHICAGO.name)
    households(:home).update!(time_zone: EASTERN.name)
    head = users(:head)

    time = head.personal_times.new
    assert time.plan(attributes(zone_shown: CHICAGO.name), household: households(:parents))

    assert_equal CHICAGO.name, head.reload.time_zone
    households(:home).update!(name: "A Head Family")
    assert_equal CHICAGO.local(2026, 11, 18, 6, 30), head.personal_times.occurring_between(WEEK).find { it.on.wday == 3 }.starts_at
  end

  test "a time that isn't saved leaves the profile zone blank" do
    head = users(:head)

    assert_not head.personal_times.new.plan(attributes(title: ""), household: households(:home))
    assert_nil head.reload.time_zone
  end

  test "clearing the profile zone is refused while personal times exist" do
    personal_time

    assert_not @user.update(time_zone: "")
    assert_includes @user.errors[:time_zone], "can't be blank while you have times on the calendar"
  end

  test "a dialog showing one zone, saved after the profile zone was set to another, re-renders instead of saving" do
    households(:home).update!(time_zone: EASTERN.name)
    head = users(:head)
    time = head.personal_times.new
    User.find(head.id).update!(time_zone: PACIFIC.name)

    assert_no_difference -> { PersonalTime.count } do
      assert_not time.plan(attributes(zone_shown: EASTERN.name), household: households(:home))
    end
    assert_equal [ "Your times are now in Pacific Time. Save again to add this time in Pacific Time." ], time.errors.full_messages
    assert_equal PACIFIC.name, time.zone_shown

    assert time.plan(attributes(zone_shown: time.zone_shown), household: households(:home))
    assert_equal PACIFIC.name, head.reload.time_zone
  end

  test "only kinds that open something keep what they open" do
    time = personal_time(kind: "personal_study", opens: personal_studies(:spouse_ransom))

    assert time.plan({ kind: "bible_reading" }, household: households(:home))
    assert_nil time.reload.opens
  end

  test "opens must be the person's own study or note" do
    time = @user.personal_times.new(attributes(kind: "personal_study", opens_key: "PersonalStudy/#{personal_studies(:head_suffering).id}"))

    assert_not time.valid?
    assert_includes time.errors[:opens], "must be one of your own studies or notes"
    assert_equal personal_notes(:spouse_grieving), @user.personal_times.new(opens_key: "PersonalNote/#{personal_notes(:spouse_grieving).id}").opens
  end

  test "at most 30 times per person" do
    30.times { personal_time }

    time = @user.personal_times.new(attributes)
    assert_not time.valid?
    assert_includes time.errors[:base], "You can have at most 30 times"
  end

  test "meeting_note_for a Thursday before a Friday midweek meeting is that week's Life and Ministry; with no meeting after it, nil" do
    @user.update!(time_zone: "UTC")
    household = households(:home)
    household.change_meeting_times(midweek_wday: 5, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    prep = personal_time(kind: "meeting_prep", title: "Meeting prep", wdays: [ 4, 6, 0 ], time_of_day: "19:00")

    meeting = prep.meeting_note_for(Date.new(2026, 11, 19), household:)
    assert_equal [ "midweek", Date.new(2026, 11, 16) ], [ meeting.kind, meeting.week_of ]
    assert_equal "weekend", prep.meeting_note_for(Date.new(2026, 11, 21), household:).kind
    assert_nil prep.meeting_note_for(Date.new(2026, 11, 22), household:)
    assert_nil prep.meeting_note_for(Date.new(2026, 11, 19), household: households(:other))
  end

  test "deleting a study keeps the time, opening nothing" do
    time = personal_time(kind: "personal_study", title: "Personal study", opens: personal_studies(:spouse_ransom))

    personal_studies(:spouse_ransom).destroy!

    assert_nil time.reload.opens
  end

  test "deleting the person deletes their times and done marks" do
    newcomer = users(:newcomer)
    newcomer.update!(time_zone: CHICAGO.name)
    newcomer.personal_times.create!(row.except(:user_id).merge(starts_on: Date.new(2026, 11, 1))).complete(on: Date.new(2026, 11, 17))

    assert_difference -> { PersonalTime.count } => -1, -> { PersonalTime::Completion.count } => -1 do
      newcomer.destroy!
    end
  end

  private
    def attributes(**overrides)
      { kind: "bible_reading", title: "Daily Bible reading", wdays: EVERY_DAY.map(&:to_s), time_of_day: "06:30", duration_minutes: "30" }.merge(overrides)
    end

    def personal_time(**overrides)
      @user.personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: EVERY_DAY, time_of_day: "06:30",
                                   starts_on: Date.new(2026, 10, 1), **overrides)
    end

    def row(**overrides)
      { user_id: @user.id, kind: "bible_reading", title: "Daily Bible reading", wdays: EVERY_DAY, time_of_day: "06:30" }.merge(overrides)
    end
end
