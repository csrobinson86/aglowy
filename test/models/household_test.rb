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

  test "database: a household without a name raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Household.insert!({ name: nil })
    end
  end
end
