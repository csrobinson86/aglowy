require "test_helper"

# Share with the family and Stop sharing, for today's brief and the household in the URL (docs/design/daily-brief.md,
# For the children, and sharing). Tuesday 17 November 2026, 9:00 AM in Hannah's zone.
class DailyBriefs::SharingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @user = users(:head)
    @user.update!(time_zone: "Central Time (US & Canada)")
    travel_to Time.utc(2026, 11, 17, 15)
    travel_to(3.days.ago) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
    @brief = DailyBrief.for(@user)
    daily_brief_writing(@brief, status: "written", result: { "thread" => "A thread", "children" => { "ask" => "Ask", "today" => "Today" } })
    sign_in identities(:head)
  end

  test "create shares today's brief with the current household, with no notification, and goes back to the brief" do
    assert_difference(-> { DailyBrief::Sharing.count }, 1) do
      assert_no_difference(-> { Notification.count }) { post household_daily_brief_sharing_path(household_id: @home) }
    end

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_equal "Shared with The Head Family.", flash[:notice]
    assert_equal [ @home ], @brief.shared_households
  end

  test "destroy stops sharing with the current household only" do
    @brief.share_with(@home)
    @brief.share_with(households(:parents))

    assert_difference(-> { DailyBrief::Sharing.count }, -1) { delete household_daily_brief_sharing_path(household_id: @home) }

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_equal "Stopped sharing with The Head Family.", flash[:notice]
    assert_equal [ households(:parents) ], @brief.reload.shared_households
  end

  test "from the evening it goes back to the evening" do
    post household_daily_brief_sharing_path(household_id: @home, part: "evening")

    assert_redirected_to household_daily_brief_path(household_id: @home, part: "evening")
  end

  test "a child is refused" do
    sign_in identities(:eli)

    assert_no_difference(-> { DailyBrief::Sharing.count }) { post household_daily_brief_sharing_path(household_id: @home) }

    assert_redirected_to household_root_path(household_id: @home)
  end

  test "with no written writing nothing is shared" do
    @brief.writings.update_all(status: "failed")

    assert_no_difference(-> { DailyBrief::Sharing.count }) { post household_daily_brief_sharing_path(household_id: @home) }

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_equal "Today's brief hasn't been written, so there's nothing to share.", flash[:alert]
  end

  test "with no brief today nothing is shared" do
    @brief.destroy!

    assert_no_difference(-> { DailyBrief::Sharing.count }) { post household_daily_brief_sharing_path(household_id: @home) }

    assert_equal "Today's brief hasn't been written, so there's nothing to share.", flash[:alert]
  end
end
