require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  test "requires a name" do
    household = Household.new(name: "")

    assert_not household.valid?
    assert_includes household.errors[:name], "can't be blank"
  end

  test "rejects an unknown time zone" do
    household = Household.new(name: "The Lees", time_zone: "Mars/Olympus Mons")

    assert_not household.valid?
    assert_includes household.errors[:time_zone], "is not included in the list"
  end

  test "create_with_head creates the household and a head membership" do
    household = Household.create_with_head(household: { name: "The Newcomers" }, head: users(:newcomer))

    assert household.persisted?
    assert_equal [ [ users(:newcomer), "head" ] ], household.memberships.map { [ it.user, it.role ] }
  end

  test "create_with_head creates nothing when the head membership is invalid" do
    assert_no_difference [ "Household.count", "Membership.count" ] do
      assert_raises ActiveRecord::RecordInvalid do
        Household.create_with_head(household: { name: "The Nobodies" }, head: nil)
      end
    end
  end

  test "add_member creates a user with no identity and a membership with the given role" do
    membership = households(:home).add_member(name: "Baby Head", role: :child)

    assert membership.persisted?
    assert membership.child?
    assert_equal "Baby Head", membership.user.name
    assert_nil membership.user.identity
  end

  test "add_member with a blank name raises RecordInvalid and creates nothing" do
    assert_no_difference [ "User.count", "Membership.count" ] do
      assert_raises ActiveRecord::RecordInvalid do
        households(:home).add_member(name: " ", role: :child)
      end
    end
  end

  test "add_member refuses the head role" do
    assert_raises ArgumentError do
      households(:home).add_member(name: "Second Head", role: :head)
    end
  end

  test "storage_used sums only this household's files, in one query" do
    photo = direct_uploaded_blob("photo.png")
    family_study_sessions(:weekly_next).add_files([ photo.signed_id ])
    households(:other).schedule_family_study(starts_on: Date.current, time_of_day: "19:00", files: [ direct_uploaded_blob("study-guide.pdf") ])
    use_home_storage(1.gigabyte)

    household = households(:home)

    assert_queries_count(1) { assert_equal 1.gigabyte + photo.byte_size, household.storage_used }
    assert_equal file_fixture("study-guide.pdf").size, households(:other).storage_used
  end

  test "links count zero" do
    households(:parents).schedule_family_study(starts_on: Date.current, time_of_day: "19:00", links: [ "https://www.jw.org/en/" ])

    assert_equal 0, households(:parents).storage_used
  end

  test "the quota is 2 GB" do
    assert_equal 2.gigabytes, households(:home).storage_quota
  end

  test "storage is nearly full from 80% of the quota" do
    household = households(:home)

    use_home_storage((household.storage_quota * 0.8).ceil - 1)
    assert_not household.storage_nearly_full?

    use_home_storage((household.storage_quota * 0.8).ceil)
    assert household.storage_nearly_full?
    assert_not household.storage_full?
    assert_equal 80, household.storage_percent_used
  end

  test "storage is full at 100% of the quota" do
    household = households(:home)

    use_home_storage(household.storage_quota - 1)
    assert_not household.storage_full?
    assert household.fits_in_storage?(1)
    assert_not household.fits_in_storage?(2)

    use_home_storage(household.storage_quota)
    assert household.storage_full?
    assert_equal 100, household.storage_percent_used
  end

  # Gotcha 14 and docs/design/invitations.md, Household settings. Rails names America/Chicago "Central Time (US & Canada)"
  # and America/New_York "Eastern Time (US & Canada)".
  test "a weekly 7:00 PM study in Chicago is still at 7:00 PM local after switching to New York" do
    travel_to Time.utc(2026, 11, 14, 12) do
      household = households(:parents)
      household.update!(time_zone: "Central Time (US & Canada)")
      study = household.schedule_family_study(frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00")

      assert household.change_time_zone("Eastern Time (US & Canada)")

      assert_equal "Eastern Time (US & Canada)", household.reload.time_zone
      sessions = study.sessions.order(:recurrence_at)
      assert_equal Time.utc(2026, 11, 18, 0), sessions.first.scheduled_at
      assert_equal Time.utc(2026, 11, 18, 0), sessions.first.recurrence_at
      sessions.each do |session|
        assert_equal [ "19:00", "Tuesday" ], session.scheduled_at.in_time_zone("America/New_York").strftime("%H:%M %A").split
        assert_equal session.scheduled_at, session.recurrence_at
      end
    end
  end

  test "a past session doesn't move" do
    travel_to Time.utc(2026, 11, 14, 12) do
      household = households(:parents)
      household.update!(time_zone: "Central Time (US & Canada)")
      study = household.schedule_family_study(frequency: "weekly", starts_on: Date.new(2026, 11, 10), time_of_day: "19:00")
      past = study.sessions.find_by!(recurrence_at: Time.utc(2026, 11, 11, 1))

      household.change_time_zone("Eastern Time (US & Canada)")

      assert_equal Time.utc(2026, 11, 11, 1), past.reload.scheduled_at
      assert_equal Time.utc(2026, 11, 11, 1), past.recurrence_at
      assert_equal Time.utc(2026, 11, 18, 0), study.sessions.find_by!(recurrence_at: Time.utc(2026, 11, 18, 0)).scheduled_at
    end
  end

  test "running the generator after the change creates no duplicates" do
    travel_to Time.utc(2026, 11, 14, 12) do
      household = households(:parents)
      household.update!(time_zone: "Central Time (US & Canada)")
      study = household.schedule_family_study(frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00")
      moved = study.sessions.find_by!(recurrence_at: Time.utc(2026, 11, 25, 1))
      moved.reschedule(on: Date.new(2026, 11, 26), at: Time.zone.parse("18:00"))

      household.change_time_zone("Eastern Time (US & Canada)")

      assert_no_difference -> { study.sessions.count } do
        study.reload.extend_sessions
      end
      assert_equal Time.utc(2026, 11, 26, 23), moved.reload.scheduled_at
      assert_equal Time.utc(2026, 11, 25, 0), moved.recurrence_at
    end
  end

  # Moved before today from a slot still ahead: the session stays put, but its slot follows the zone, or the generator
  # would bring the slot back (gotcha 21).
  test "a session moved into the past keeps its time but its slot ahead follows the new zone" do
    travel_to Time.utc(2026, 11, 14, 12) do
      household = households(:parents)
      household.update!(time_zone: "Central Time (US & Canada)")
      study = household.schedule_family_study(frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00")
      moved = study.sessions.find_by!(recurrence_at: Time.utc(2026, 11, 18, 1))
      moved.update!(scheduled_at: Time.utc(2026, 11, 13, 1), detached_at: Time.current)

      household.change_time_zone("Eastern Time (US & Canada)")

      assert_equal Time.utc(2026, 11, 13, 1), moved.reload.scheduled_at
      assert_equal Time.utc(2026, 11, 18, 0), moved.recurrence_at
      assert_no_difference -> { study.sessions.count } do
        study.reload.extend_sessions
      end
    end
  end

  # The generator starts from today, so the slot of a session already over today must follow the zone too. In Tokyo,
  # 7:00 AM on 15 November is 22:00 UTC on the 14th; after the move to Chicago, the next run builds 7:00 AM on the 15th
  # in Chicago, which must find its slot taken.
  test "a session already over today keeps its time and isn't built again after a move west" do
    household = households(:parents)
    household.update!(time_zone: "Tokyo")
    study = travel_to(Time.utc(2026, 11, 14, 12)) { household.schedule_family_study(frequency: "daily", starts_on: Date.new(2026, 11, 15), time_of_day: "07:00") }
    over = study.sessions.find_by!(recurrence_at: Time.utc(2026, 11, 14, 22))

    travel_to(Time.utc(2026, 11, 14, 23)) { household.change_time_zone("Central Time (US & Canada)") }

    assert_equal Time.utc(2026, 11, 14, 22), over.reload.scheduled_at
    assert_equal Time.utc(2026, 11, 15, 13), over.recurrence_at
    travel_to Time.utc(2026, 11, 15, 3) do
      assert_no_difference -> { study.sessions.count } do
        study.reload.extend_sessions
      end
    end
  end

  # DST ends in London on 25 October 2026 and in Chicago on 1 November, so in between the two are five hours apart, not
  # six: shifting every session by one offset would put one side an hour out.
  test "a session in the week of a DST change keeps its local time" do
    travel_to Time.utc(2026, 10, 20, 12) do
      household = households(:parents)
      household.update!(time_zone: "Central Time (US & Canada)")
      study = household.schedule_family_study(frequency: "weekly", starts_on: Date.new(2026, 10, 28), time_of_day: "19:00")
      in_the_dst_week = study.sessions.find_by!(recurrence_at: Time.utc(2026, 10, 29, 0))
      after_it = study.sessions.find_by!(recurrence_at: Time.utc(2026, 11, 5, 1))

      household.change_time_zone("London")

      assert_equal Time.utc(2026, 10, 28, 19), in_the_dst_week.reload.scheduled_at
      assert_equal Time.utc(2026, 10, 28, 19), in_the_dst_week.recurrence_at
      assert_equal Time.utc(2026, 11, 4, 19), after_it.reload.scheduled_at
      assert_equal Time.utc(2026, 11, 4, 19), after_it.recurrence_at
    end
  end

  # On 14 March 2027 Chicago skips 2:00 to 3:00 AM, so that day's 2:30 slot is stored at 3:30. In UTC the generator
  # builds it at 2:30, so that's where the slot must go; the session keeps the 3:30 it showed.
  test "a slot in a spring-forward gap moves to where the generator builds it in the new zone" do
    travel_to Time.utc(2027, 3, 10, 12) do
      household = households(:parents)
      household.update!(time_zone: "Central Time (US & Canada)")
      study = household.schedule_family_study(frequency: "daily", starts_on: Date.new(2027, 3, 13), time_of_day: "02:30")
      in_the_gap = study.sessions.find_by!(recurrence_at: Time.utc(2027, 3, 14, 8, 30))

      assert household.change_time_zone("UTC")

      assert_equal Time.utc(2027, 3, 14, 3, 30), in_the_gap.reload.scheduled_at
      assert_equal Time.utc(2027, 3, 14, 2, 30), in_the_gap.recurrence_at
      assert_no_difference -> { study.sessions.count } do
        study.reload.extend_sessions
      end
    end
  end

  # Samoa is 13 hours ahead of UTC and American Samoa 11 behind, so each day's 7:00 PM lands on the next day's slot,
  # which has to move out of the way first.
  test "a daily study keeps its local time between zones a day apart" do
    travel_to Time.utc(2026, 11, 14, 12) do
      household = households(:parents)
      household.update!(time_zone: "Samoa")
      study = household.schedule_family_study(frequency: "daily", starts_on: Date.new(2026, 11, 16), time_of_day: "19:00")

      assert household.change_time_zone("American Samoa")

      study.sessions.each do |session|
        assert_equal "19:00", session.scheduled_at.in_time_zone("Pacific/Pago_Pago").strftime("%H:%M")
        assert_equal session.scheduled_at, session.recurrence_at
      end
      assert_no_difference -> { study.sessions.count } do
        study.reload.extend_sessions
      end
    end
  end

  # Back the other way, today's 7:00 PM session lands on the slot of yesterday's, which is over and keeps its slot.
  test "a zone change that would put two sessions in one slot is refused and moves nothing" do
    household = households(:parents)
    household.update!(time_zone: "American Samoa")
    study = travel_to(Time.utc(2026, 11, 10, 12)) { household.schedule_family_study(frequency: "daily", starts_on: Date.new(2026, 11, 10), time_of_day: "19:00") }

    travel_to Time.utc(2026, 11, 14, 12) do
      assert_no_changes -> { study.sessions.order(:recurrence_at).pluck(:scheduled_at, :recurrence_at) } do
        assert_not household.change_time_zone("Samoa")
      end
      assert_includes household.errors[:time_zone], "can't be used: it's a day from the current zone, so a daily study would have two sessions in one slot"
      assert_equal "American Samoa", household.reload.time_zone
    end
  end

  test "another household's sessions don't move" do
    travel_to Time.utc(2026, 11, 14, 12) do
      other = households(:other).schedule_family_study(starts_on: Date.new(2026, 11, 17), time_of_day: "19:00").sessions.sole

      households(:parents).change_time_zone("Eastern Time (US & Canada)")

      assert_equal Time.utc(2026, 11, 17, 19), other.reload.scheduled_at
    end
  end

  test "update_settings renames the household" do
    household = households(:home)

    assert household.update_settings(name: "The Riveras", time_zone: household.time_zone)
    assert_equal "The Riveras", household.reload.name
  end

  test "update_settings with a blank name or an unknown zone saves nothing and moves nothing" do
    travel_to Time.utc(2026, 11, 14, 12) do
      household = households(:parents)
      session = household.schedule_family_study(starts_on: Date.new(2026, 11, 17), time_of_day: "19:00").sessions.sole

      assert_not household.update_settings(name: " ", time_zone: "Eastern Time (US & Canada)")
      assert_includes household.errors[:name], "can't be blank"
      assert_not household.reload.change_time_zone("Atlantis")
      assert_includes household.errors[:time_zone], "is not included in the list"

      assert_equal [ "The Grandparent Family", "UTC" ], [ household.reload.name, household.time_zone ]
      assert_equal Time.utc(2026, 11, 17, 19), session.reload.scheduled_at
    end
  end

  # Meeting times (docs/design/meeting-helper.md, Meeting times). The week of Monday 16 November 2026 in Chicago, with
  # the midweek meeting on Thursday at 7:00 PM and the weekend meeting on Sunday at 10:00 AM unless a test says otherwise.
  CHICAGO = ActiveSupport::TimeZone["Central Time (US & Canada)"]

  def household_meeting(midweek: [ 4, "19:00" ], weekend: [ 0, "10:00" ])
    households(:home).tap do |household|
      household.update!(time_zone: CHICAGO.name)
      assert household.change_meeting_times(midweek_wday: midweek.first, midweek_time: midweek.last, weekend_wday: weekend.first, weekend_time: weekend.last)
    end
  end

  def chicago(*args) = CHICAGO.local(2026, *args)

  test "with no times, current_or_next_meeting is nil" do
    household = households(:home)

    assert_not household.meeting_times_set?
    assert_nil household.current_or_next_meeting
    assert_not household.meeting_day?
  end

  test "change_meeting_times saves all four, and meeting_times_set? is true" do
    household = household_meeting

    household.reload
    assert household.meeting_times_set?
    assert_equal [ 4, 0 ], [ household.midweek_meeting_wday, household.weekend_meeting_wday ]
    assert_equal [ "19:00", "10:00" ], [ household.midweek_meeting_time, household.weekend_meeting_time ].map { it.strftime("%H:%M") }
  end

  test "change_meeting_times with a missing one saves nothing and puts the error on its field" do
    household = households(:home)

    assert_not household.change_meeting_times(midweek_wday: 4, midweek_time: "", weekend_wday: 0, weekend_time: "10:00")
    assert_includes household.errors[:midweek_meeting_time], "can't be blank"
    assert_not household.reload.meeting_times_set?
  end

  test "change_meeting_times refuses a day that isn't 0 to 6" do
    household = households(:home)

    assert_not household.change_meeting_times(midweek_wday: 7, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    assert_includes household.errors[:midweek_meeting_wday], "is not included in the list"
  end

  test "midweek Thursday 7:00 PM: on Thursday at 6 PM, it's that evening's meeting" do
    household = household_meeting
    meeting = household.current_or_next_meeting(chicago(11, 19, 18))

    assert_equal "midweek", meeting.kind
    assert_equal chicago(11, 19, 19), meeting.starts_at
    assert_equal chicago(11, 19, 21), meeting.ends_at
    assert_equal "Midweek meeting", meeting.title
  end

  test "at 8:30 PM, and at 11:30 PM that Thursday, it's still the same meeting" do
    household = household_meeting

    [ chicago(11, 19, 20, 30), chicago(11, 19, 23, 30) ].each do |now|
      assert_equal chicago(11, 19, 19), household.current_or_next_meeting(now).starts_at, "at #{now}"
    end
    assert_equal chicago(11, 19).end_of_day, household.current_or_next_meeting(chicago(11, 19, 23, 30)).current_until
  end

  test "on Friday morning, it's the weekend meeting" do
    meeting = household_meeting.current_or_next_meeting(chicago(11, 20, 8))

    assert_equal "weekend", meeting.kind
    assert_equal chicago(11, 22, 10), meeting.starts_at
    assert_equal "Weekend meeting", meeting.title
  end

  test "a weekend meeting on Sunday at 11:30 PM is still current at 12:15 AM Monday" do
    meeting = household_meeting(weekend: [ 0, "23:30" ]).current_or_next_meeting(chicago(11, 23, 0, 15))

    assert_equal "weekend", meeting.kind
    assert_equal chicago(11, 22, 23, 30), meeting.starts_at
    assert_equal chicago(11, 23, 1, 30), meeting.current_until
  end

  # A Saturday weekend meeting, so the Sunday has no meeting: the next one is in the following week.
  test "on a Sunday after the weekend meeting ends, it's next week's midweek meeting" do
    meeting = household_meeting(weekend: [ 6, "10:00" ]).current_or_next_meeting(chicago(11, 22, 12))

    assert_equal "midweek", meeting.kind
    assert_equal chicago(11, 26, 19), meeting.starts_at
  end

  test "once a Sunday meeting's day is over, it's next week's midweek meeting" do
    meeting = household_meeting.current_or_next_meeting(chicago(11, 23, 0, 0))

    assert_equal [ "midweek", chicago(11, 26, 19) ], [ meeting.kind, meeting.starts_at ]
  end

  test "a Sunday meeting's week_of is the Monday before" do
    meeting = household_meeting.current_or_next_meeting(chicago(11, 22, 9))

    assert_equal Date.new(2026, 11, 22), meeting.starts_at.to_date
    assert_equal Date.new(2026, 11, 16), meeting.week_of
  end

  # Daylight saving time ends at 2:00 AM on Sunday 1 November 2026 in Chicago (Trap 5).
  test "the week daylight saving time ends, a meeting is still at 7:00 PM local" do
    meeting = household_meeting(weekend: [ 0, "19:00" ]).current_or_next_meeting(chicago(10, 30, 12))

    assert_equal chicago(11, 1, 19), meeting.starts_at
    assert_equal [ 19, 0 ], [ meeting.starts_at.hour, meeting.starts_at.min ]
    assert_equal Time.utc(2026, 11, 2, 1), meeting.starts_at.utc
  end

  test "meeting_day? is true all day on the meeting's day, including after it ends, and false the day before" do
    household = household_meeting

    assert household.meeting_day?(chicago(11, 19, 0, 1))
    assert household.meeting_day?(chicago(11, 19, 22))
    assert household.meeting_day?(chicago(11, 19, 23, 59))
    assert_not household.meeting_day?(chicago(11, 18, 23, 59))
  end

  test "meeting_day? defaults to now" do
    household = household_meeting

    travel_to(chicago(11, 19, 12)) { assert household.meeting_day? }
    travel_to(chicago(11, 20, 12)) { assert_not household.meeting_day? }
  end

  test "database: a midweek meeting day outside 0 to 6 raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      households(:home).update_columns(midweek_meeting_wday: 7, midweek_meeting_time: "19:00", weekend_meeting_wday: 0, weekend_meeting_time: "10:00")
    end
  end

  test "database: a weekend meeting day outside 0 to 6 raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      households(:home).update_columns(midweek_meeting_wday: 4, midweek_meeting_time: "19:00", weekend_meeting_wday: 7, weekend_meeting_time: "10:00")
    end
  end

  test "database: setting only midweek_meeting_wday raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      households(:home).update_column(:midweek_meeting_wday, 4)
    end
  end

  test "database: a household without a name raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Household.insert!({ name: nil })
    end
  end
end
