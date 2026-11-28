require "test_helper"

# Briefs are kept 60 days, only so the next ones can avoid repeating them (docs/design/daily-brief.md, The purpose).
class DailyBrief::PurgeJobTest < ActiveJob::TestCase
  setup do
    @user = users(:head)
    @user.update!(time_zone: "Central Time (US & Canada)")
    travel_to Time.utc(2026, 11, 17, 15)
    @plan = travel_to(70.days.ago) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
  end

  test "a brief 61 days old goes with its writings and their chats; one 59 days old stays; the person's plan stays" do
    old, recent = [ 61, 59 ].map { |days| travel_to(days.days.ago) { DailyBrief.for(@user) } }
    writings = Array.new(2) { daily_brief_writing(old, status: "written", result: { "thread" => "Old." }) }
    kept = daily_brief_writing(recent, status: "written", result: { "thread" => "Recent." })

    DailyBrief::PurgeJob.perform_now

    assert_not DailyBrief.exists?(old.id)
    writings.each do
      assert_not DailyBrief::Writing.exists?(it.id)
      assert_not Chat.exists?(it.chat_id)
    end
    assert DailyBrief.exists?(recent.id)
    assert DailyBrief::Writing.exists?(kept.id)
    assert Chat.exists?(kept.chat_id)
    assert_equal @plan, @user.reload.daily_brief_plan
    assert_equal 7, @plan.days.count
  end

  test "one that raises is reported and the next is still deleted" do
    briefs = [ 62, 61 ].map { |days| travel_to(days.days.ago) { DailyBrief.for(@user) } }
    first, second = briefs.sort_by(&:id)
    # A row with no cascade still pointing at the first one's chat: deleting the chat fails.
    personal_studies(:head_suffering).update_column(:chat_id, daily_brief_writing(first, status: "written", result: { "thread" => "Stuck." }).chat_id)

    assert_error_reported(ActiveRecord::InvalidForeignKey) { DailyBrief::PurgeJob.perform_now }

    assert DailyBrief.exists?(first.id)
    assert_not DailyBrief.exists?(second.id)
  end

  test "expired is the briefs dated more than 60 days ago" do
    sixty, sixty_one = [ 60, 61 ].map { |days| travel_to(days.days.ago) { DailyBrief.for(@user) } }

    assert_equal [ sixty_one ], DailyBrief.expired.to_a
    assert_not_includes DailyBrief.expired, sixty
  end
end
