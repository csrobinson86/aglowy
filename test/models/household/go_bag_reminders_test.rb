require "test_helper"

# The go-bag use-by reminder (docs/design/go-bags.md, The use-by reminder): each day at 8 AM in the household's zone, and
# right away when an item is saved or ticked with a date already close, one notification to each active head and adult
# for each item we have whose use-by date is from today to 30 days later. Once for each date.
class Household::GoBagRemindersTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CHICAGO = ActiveSupport::TimeZone["Central Time (US & Canada)"]

  setup do
    @household = households(:home)
    @household.update!(time_zone: CHICAGO.name)
    @water = go_bag_items(:water)
  end

  test "heads and adults get it, and children don't" do
    @water.update!(use_by: Date.new(2026, 12, 7))

    eight_am_on_november_17 { @household.remind_about_go_bag_use_by }

    assert_equal [ users(:head), users(:spouse) ].sort_by(&:id), reminders_for(@water).map(&:user).sort_by(&:id)
    assert reminders_for(@water).all? { it.kind == "go_bag_use_by" && it.household == @household }
    assert_equal [ { "use_by" => "2026-12-07" } ], reminders_for(@water).map(&:data).uniq
    assert_equal [ "go_bag_use_by:#{@water.id}:2026-12-07" ], reminders_for(@water).map(&:dedupe_key).uniq
  end

  test "an item 30 days out is included and one 31 days out isn't" do
    @water.update!(use_by: Date.new(2026, 12, 17))
    go_bag_items(:batteries).update!(use_by: Date.new(2026, 12, 18))

    eight_am_on_november_17 { @household.remind_about_go_bag_use_by }

    assert_equal 2, reminders_for(@water).count
    assert_not Notification.exists?(subject: go_bag_items(:batteries))
  end

  test "a date already past, an item we don't have and an item with no date get nothing" do
    @water.update!(use_by: Date.new(2026, 11, 16))
    go_bag_items(:flashlight).update!(use_by: Date.new(2026, 11, 20))

    eight_am_on_november_17 { @household.remind_about_go_bag_use_by }

    assert_not Notification.exists?(subject: [ @water, go_bag_items(:flashlight), go_bag_items(:batteries) ])
  end

  test "today's date is included" do
    @water.update!(use_by: Date.new(2026, 11, 17))

    eight_am_on_november_17 { @household.remind_about_go_bag_use_by }

    assert_equal 2, reminders_for(@water).count
  end

  test "running twice sends once" do
    @water.update!(use_by: Date.new(2026, 12, 7))

    eight_am_on_november_17 do
      @household.remind_about_go_bag_use_by
      @household.remind_about_go_bag_use_by
    end

    assert_equal 2, reminders_for(@water).count
  end

  test "a changed date sends again" do
    @water.update!(use_by: Date.new(2026, 12, 7))
    eight_am_on_november_17 { @household.remind_about_go_bag_use_by }

    @water.update!(use_by: Date.new(2026, 12, 1))
    travel_to(CHICAGO.local(2026, 11, 18, 8, 20)) { @household.remind_about_go_bag_use_by }

    assert_equal [ "2026-12-01", "2026-12-07" ], reminders_for(@water).map { it.data["use_by"] }.uniq.sort
    assert_equal 4, reminders_for(@water).count
  end

  test "another household's items are untouched" do
    theirs = households(:other).go_bags.create!(name: "Their bag", created_by: users(:outsider)).items.create!(name: "Water", use_by: Date.new(2026, 12, 7))
    theirs.acquire(by: users(:outsider))
    @water.update!(use_by: Date.new(2026, 12, 7))

    eight_am_on_november_17 { @household.remind_about_go_bag_use_by }

    assert_not Notification.exists?(subject: theirs)
    assert_equal [ @household ], Notification.where(kind: "go_bag_use_by").map(&:household).uniq
  end

  test "ticking an item with a use-by date of today, after 8 AM, sends it right away" do
    flashlight = go_bag_items(:flashlight)
    flashlight.update!(use_by: Date.new(2026, 11, 17))

    travel_to(CHICAGO.local(2026, 11, 17, 15)) do
      perform_enqueued_jobs(only: GoBag::Item::UseByReminderJob) { flashlight.acquire(by: users(:spouse)) }
    end

    assert_equal [ users(:head), users(:spouse) ].sort_by(&:id), reminders_for(flashlight).map(&:user).sort_by(&:id)
    assert_equal [ "go_bag_use_by:#{flashlight.id}:2026-11-17" ], reminders_for(flashlight).map(&:dedupe_key).uniq
  end

  test "saving an item with a use-by date of today, after 8 AM, sends it right away, and the next day's job doesn't send it again" do
    travel_to(CHICAGO.local(2026, 11, 17, 15)) do
      perform_enqueued_jobs(only: GoBag::Item::UseByReminderJob) do
        @water.assign_attributes(use_by: Date.new(2026, 11, 17))
        assert @water.save_with(have: nil, by: users(:spouse))
      end
    end
    assert_equal 2, reminders_for(@water).count

    travel_to(CHICAGO.local(2026, 11, 18, 8, 20)) { Notification::GoBagUseByJob.perform_now }

    assert_equal 2, reminders_for(@water).count
  end

  test "a date 10 days out saved after 8 AM is sent right away, and the next day's job finds it already sent" do
    travel_to(CHICAGO.local(2026, 11, 17, 15)) do
      perform_enqueued_jobs(only: GoBag::Item::UseByReminderJob) do
        @water.assign_attributes(use_by: Date.new(2026, 11, 27))
        assert @water.save_with(have: "1", by: users(:spouse))
      end
    end

    travel_to(CHICAGO.local(2026, 11, 18, 8, 20)) { Notification::GoBagUseByJob.perform_now }

    assert_equal 2, reminders_for(@water).count
  end

  test "a new item saved ticked with a close date is sent right away" do
    item = go_bags(:family).items.new(name: "Energy bars", use_by: Date.new(2026, 11, 30))

    travel_to(CHICAGO.local(2026, 11, 17, 15)) do
      perform_enqueued_jobs(only: GoBag::Item::UseByReminderJob) { assert item.save_with(have: "1", by: users(:spouse)) }
    end

    assert_equal 2, reminders_for(item).count
  end

  test "a date 31 days out sends nothing on save" do
    travel_to(CHICAGO.local(2026, 11, 17, 15)) do
      assert_no_enqueued_jobs(only: GoBag::Item::UseByReminderJob) do
        @water.assign_attributes(use_by: Date.new(2026, 12, 18))
        assert @water.save_with(have: "1", by: users(:spouse))
      end
    end

    assert_not Notification.exists?(subject: @water)
  end

  test "saving an item unticked, with a close date, sends nothing" do
    travel_to(CHICAGO.local(2026, 11, 17, 15)) do
      assert_no_enqueued_jobs(only: GoBag::Item::UseByReminderJob) do
        @water.assign_attributes(use_by: Date.new(2026, 11, 20))
        assert @water.save_with(have: "0", by: users(:spouse))
      end
    end
  end

  test "an item unticked or given a later date after the reminder was asked for isn't reminded about" do
    @water.update!(use_by: Date.new(2026, 12, 7))
    batteries = go_bag_items(:batteries)
    batteries.update!(use_by: Date.new(2026, 12, 7))
    GoBag::Item.find(@water.id).unacquire
    GoBag::Item.find(batteries.id).update!(use_by: Date.new(2027, 3, 1))

    eight_am_on_november_17 do
      @water.remind_about_use_by_now
      batteries.remind_about_use_by_now
    end

    assert_not Notification.exists?(subject: [ @water, batteries ])
  end

  test "an item removed after the reminder was asked for isn't reminded about" do
    @water.update!(use_by: Date.new(2026, 12, 7))
    GoBag::Item.find(@water.id).destroy!

    eight_am_on_november_17 { @water.remind_about_use_by_now }

    assert_not Notification.exists?(subject_type: "GoBag::Item", subject_id: @water.id)
  end

  test "a reminder job for an item removed in the meantime does nothing" do
    @water.update!(use_by: Date.new(2026, 11, 20))
    travel_to(CHICAGO.local(2026, 11, 17, 15)) { @water.remind_about_use_by_later }
    @water.destroy!

    assert_nothing_raised { perform_enqueued_jobs(only: GoBag::Item::UseByReminderJob) }
    assert_not Notification.exists?(subject_type: "GoBag::Item", subject_id: @water.id)
  end

  private
    def reminders_for(item)
      Notification.where(subject: item)
    end

    def eight_am_on_november_17(&)
      travel_to(CHICAGO.local(2026, 11, 17, 8, 20), &)
    end
end
