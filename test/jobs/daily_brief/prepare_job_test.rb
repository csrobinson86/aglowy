require "test_helper"

# The morning job (docs/design/daily-brief.md, The morning job; Traps 6 and 13). Tuesday 17 November 2026; Hannah's
# plan is ready by 5:00 AM Central Time and was started on the 1st.
class DailyBrief::PrepareJobTest < ActiveJob::TestCase
  setup do
    @user = users(:head)
    @user.update!(time_zone: "Central Time (US & Canada)")
    @plan = travel_to(central(9) - 16.days) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
  end

  test "makes a brief for a due plan and none for one that isn't" do
    users(:spouse).update!(time_zone: "Central Time (US & Canada)")
    later = travel_to(central(9) - 16.days) { DailyBrief::Plan.start(users(:spouse), starter: "basics") }
    later.update!(ready_at_minutes: 480)

    travel_to(central(4, 30)) { DailyBrief::PrepareJob.perform_now }

    assert_equal [ Date.new(2026, 11, 17) ], @user.daily_briefs.pluck(:on)
    assert_empty users(:spouse).daily_briefs
  end

  test "someone no longer a head or adult in any household gets none, and keeps their plan" do
    @user.memberships.update_all(active: false)

    travel_to(central(5)) do
      assert_no_difference(-> { DailyBrief.count }) { DailyBrief::PrepareJob.perform_now }
    end
    assert_not @plan.reload.paused?
  end

  test "running twice makes one" do
    travel_to(central(5)) do
      assert_difference(-> { DailyBrief.count }, 1) { 2.times { DailyBrief::PrepareJob.perform_now } }
    end
  end

  test "seven unseen in a row pauses it with unseen and makes none" do
    unseen_mornings(7)

    travel_to(central(5)) do
      assert_no_difference(-> { DailyBrief.count }) { DailyBrief::PrepareJob.perform_now }
    end
    assert_equal "unseen", @plan.reload.pausing.reason
  end

  test "six unseen still makes one" do
    unseen_mornings(6)

    travel_to(central(5)) do
      assert_difference(-> { DailyBrief.count }) { DailyBrief::PrepareJob.perform_now }
    end
    assert_not @plan.reload.paused?
  end

  test "after resume, the seven unseen briefs from before don't pause it again" do
    unseen_mornings(7)
    travel_to(central(5)) { DailyBrief::PrepareJob.perform_now }
    assert @plan.reload.paused?
    travel_to(central(8)) { @plan.resume }

    travel_to(central(5) + 1.day) do
      assert_difference(-> { DailyBrief.count }) { DailyBrief::PrepareJob.perform_now }
    end
    assert_not @plan.reload.paused?
  end

  test "a plan started today gets none" do
    @plan.destroy!
    travel_to(central(3)) { DailyBrief::Plan.start(@user, starter: "basics") }

    travel_to(central(9)) do
      assert_no_difference(-> { DailyBrief.count }) { DailyBrief::PrepareJob.perform_now }
    end
  end

  test "a paused plan gets none" do
    @plan.pause(reason: "chosen")

    travel_to(central(9)) do
      assert_no_difference(-> { DailyBrief.count }) { DailyBrief::PrepareJob.perform_now }
    end
  end

  test "seven unseen before today and today's brief already made by Prepare today's brief doesn't pause" do
    unseen_mornings(7)
    travel_to(central(4)) { DailyBrief.for(@user) }

    travel_to(central(5)) do
      assert_no_difference(-> { DailyBrief.count }) { DailyBrief::PrepareJob.perform_now }
    end
    assert_not @plan.reload.paused?
  end

  test "starts a writing for someone with the AI terms, and none without" do
    users(:spouse).update!(time_zone: "Central Time (US & Canada)")
    travel_to(central(9) - 16.days) { DailyBrief::Plan.start(users(:spouse), starter: "basics") }
    @user.accept_ai_terms(understood: "1")

    travel_to(central(5)) do
      assert_enqueued_jobs(1, only: DailyBrief::WriteJob) { DailyBrief::PrepareJob.perform_now }
    end

    assert_equal 1, @user.daily_briefs.sole.writings.count
    assert_empty users(:spouse).daily_briefs.sole.writings
  end

  test "running twice starts one writing" do
    @user.accept_ai_terms(understood: "1")

    travel_to(central(5)) do
      assert_difference(-> { DailyBrief::Writing.count }, 1) { 2.times { DailyBrief::PrepareJob.perform_now } }
    end
  end

  test "a brief made earlier with no writing gets one on the next run" do
    travel_to(central(5)) { DailyBrief::PrepareJob.perform_now }
    @user.accept_ai_terms(understood: "1")

    travel_to(central(5, 15)) do
      assert_difference(-> { DailyBrief::Writing.count }, 1) { DailyBrief::PrepareJob.perform_now }
    end
  end

  test "with six earlier unseen briefs and today's, the seventh, made with no writing, the next run starts the writing and doesn't pause" do
    unseen_mornings(6)
    travel_to(central(5)) { DailyBrief::PrepareJob.perform_now }
    @user.accept_ai_terms(understood: "1")

    travel_to(central(5, 15) + 1.minute) do
      assert_difference(-> { DailyBrief::Writing.count }, 1) { DailyBrief::PrepareJob.perform_now }
    end
    assert_not @plan.reload.paused?
  end

  test "a brief whose writing failed isn't written again by the job" do
    @user.accept_ai_terms(understood: "1")
    travel_to(central(5)) { DailyBrief::PrepareJob.perform_now }
    @user.daily_briefs.sole.writings.sole.update!(status: "failed")

    travel_to(central(5, 15)) do
      assert_no_difference(-> { DailyBrief::Writing.count }) { DailyBrief::PrepareJob.perform_now }
    end
  end

  test "one that raises is reported and the next still gets its brief" do
    users(:spouse).update!(time_zone: "Central Time (US & Canada)")
    other = travel_to(central(9) - 16.days) { DailyBrief::Plan.start(users(:spouse), starter: "basics") }
    first, second = [ @plan, other ].sort_by(&:id).map(&:user)
    brief_for = DailyBrief.method(:for)
    fail_for_first = ->(user, **options) { user == first ? raise("brief failed") : brief_for.call(user, **options) }

    travel_to(central(5)) do
      assert_error_reported { DailyBrief.stub(:for, fail_for_first) { DailyBrief::PrepareJob.perform_now } }
    end

    assert_empty first.daily_briefs
    assert_equal [ Date.new(2026, 11, 17) ], second.daily_briefs.pluck(:on)
  end

  test "runs every 15 minutes" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig("production", "prepare_daily_briefs")

    assert_equal "DailyBrief::PrepareJob", task["class"]
    assert_equal "every 15 minutes", task["schedule"]
  end

  private
    def central(hour, minute = 0)
      ActiveSupport::TimeZone["Central Time (US & Canada)"].local(2026, 11, 17, hour, minute)
    end

    # The job's brief on each of the mornings before the 17th, none of them seen.
    def unseen_mornings(count)
      count.downto(1) { |ago| travel_to(central(5) - ago.days) { DailyBrief::PrepareJob.perform_now } }
    end
end
