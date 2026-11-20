require "test_helper"

# Get ready's switch, which can only be on while the meeting helper is (docs/design/meeting-prep.md, Models; Trap 8).
class Household::MeetingPrepTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @home = households(:home)
    @home.enable_meeting_helper(by: users(:head))
  end

  # Turning it on prepares this week straight away (docs/design/meeting-prep.md, The Settings check box).
  test "turning it on enqueues this week's preparation, once it's committed" do
    @home.change_meeting_times(midweek_wday: 2, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")

    assert_enqueued_with(job: PrepWeek::PrepareJob, args: [ @home ]) { @home.enable_meeting_prep(by: users(:head)) }
  end

  test "turning it on when it's already on enqueues nothing" do
    @home.change_meeting_times(midweek_wday: 2, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @home.enable_meeting_prep(by: users(:head))

    assert_no_enqueued_jobs(only: PrepWeek::PrepareJob) { @home.enable_meeting_prep(by: users(:spouse)) }
  end

  test "nothing is enqueued when turning it on rolls back" do
    @home.change_meeting_times(midweek_wday: 2, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")

    assert_no_enqueued_jobs(only: PrepWeek::PrepareJob) do
      Household.transaction do
        @home.enable_meeting_prep(by: users(:head))
        raise ActiveRecord::Rollback
      end
    end
  end

  test "turning it on before meeting times are set enqueues nothing" do
    assert_not @home.meeting_times_set?

    assert_no_enqueued_jobs(only: PrepWeek::PrepareJob) { @home.enable_meeting_prep(by: users(:head)) }
    assert @home.meeting_prep?
  end

  test "enabling records who turned it on" do
    @home.enable_meeting_prep(by: users(:spouse))

    assert @home.meeting_prep?
    assert_equal users(:spouse), @home.reload.meeting_prep.enabled_by
  end

  test "enabling twice makes one, and keeps the first person who turned it on" do
    @home.enable_meeting_prep(by: users(:head))
    @home.enable_meeting_prep(by: users(:spouse))

    assert_equal 1, Household::MeetingPrep.where(household: @home).count
    assert_equal users(:head), @home.reload.meeting_prep.enabled_by
  end

  test "enabling with the helper off returns false and saves nothing" do
    @home.disable_meeting_helper

    assert_equal false, @home.enable_meeting_prep(by: users(:head))
    assert_not Household::MeetingPrep.exists?(household: @home)
    assert_not @home.meeting_prep?
  end

  test "meeting_prep? is false while Get ready's switch is missing" do
    assert @home.meeting_helper?
    assert_not @home.meeting_prep?
  end

  # Only a direct write can get here: every way through the app turns both off together.
  test "meeting_prep? is false while the helper's switch is missing" do
    @home.enable_meeting_prep(by: users(:head))
    Household::MeetingHelper.where(household: @home).delete_all

    assert_not @home.reload.meeting_prep?
  end

  test "disabling Get ready removes it and leaves the helper on" do
    @home.enable_meeting_prep(by: users(:head))

    @home.disable_meeting_prep

    assert_not @home.meeting_prep?
    assert_not Household::MeetingPrep.exists?(household: @home)
    assert @home.meeting_helper?
  end

  test "disabling the helper removes Get ready too" do
    @home.enable_meeting_prep(by: users(:head))

    @home.disable_meeting_helper

    assert_not @home.meeting_prep?
    assert_not Household::MeetingPrep.exists?(household: @home)
    assert_not Household::MeetingHelper.exists?(household: @home)
  end

  test "destroying the household deletes its Get ready switch" do
    @home.enable_meeting_prep(by: users(:head))

    assert_difference("Household::MeetingPrep.count", -1) { @home.destroy }
  end

  test "database: the unique index on household_id rejects a second row" do
    @home.enable_meeting_prep(by: users(:head))

    assert_raises ActiveRecord::RecordNotUnique do
      Household::MeetingPrep.insert!({ household_id: @home.id, enabled_by_id: users(:spouse).id })
    end
  end

  test "database: a Get ready switch without enabled_by raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Household::MeetingPrep.insert!({ household_id: @home.id, enabled_by_id: nil })
    end
  end

  test "database: a Get ready switch without a household raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Household::MeetingPrep.insert!({ household_id: nil, enabled_by_id: users(:head).id })
    end
  end

  test "database: a household that doesn't exist raises InvalidForeignKey" do
    assert_raises ActiveRecord::InvalidForeignKey do
      Household::MeetingPrep.insert!({ household_id: SecureRandom.uuid_v7, enabled_by_id: users(:head).id })
    end
  end

  test "database: an enabled_by that isn't a user raises InvalidForeignKey" do
    assert_raises ActiveRecord::InvalidForeignKey do
      Household::MeetingPrep.insert!({ household_id: @home.id, enabled_by_id: SecureRandom.uuid_v7 })
    end
  end
end

# An enable and a helper disable at once never leave Get ready on: the disable holds the household's row lock while it
# deletes both switches, so an enable that comes in then waits, and finds the helper off once it gets the lock
# (docs/design/meeting-prep.md, Models; Trap 8). Each thread needs its own committed view of the rows, so this test
# runs outside a transaction.
class Household::MeetingPrepConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @home = households(:home)
    @home.enable_meeting_helper(by: users(:head))
  end

  # Fixtures are committed in this test, so take the switches away for the tests that run after it.
  teardown do
    Household::MeetingPrep.where(household: @home).delete_all
    Household::MeetingHelper.where(household: @home).delete_all
  end

  test "an enable that waits on the lock while the helper is disabled finds it off and saves nothing" do
    spouse, enabler = users(:spouse), nil

    # The outer transaction keeps the disable's lock until the enable is waiting on it.
    Household.transaction do
      @home.disable_meeting_helper
      enabler = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { Household.find(@home.id).enable_meeting_prep(by: spouse) }
      end
      assert_nil enabler.join(0.5), "the enable waits for the disable's lock"
    end

    assert_equal false, enabler.value
    assert_not Household::MeetingPrep.exists?(household: @home)
    assert_not @home.reload.meeting_prep?
  end

  # An enable holds the household's lock from its insert to its lookup of the row it found, so a Get ready disable
  # waits for it rather than deleting that row in between.
  test "a Get ready disable waits on the household's lock, then turns Get ready off and leaves the helper on" do
    @home.enable_meeting_prep(by: users(:head))
    disabler = nil

    Household.transaction do
      @home.lock!
      disabler = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { Household.find(@home.id).disable_meeting_prep }
      end
      assert_nil disabler.join(0.5), "the disable waits for the household's lock"
    end

    disabler.join
    assert_not Household::MeetingPrep.exists?(household: @home)
    assert @home.reload.meeting_helper?
  end
end
