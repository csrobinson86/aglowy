require "test_helper"

class Goals::SharingsControllerTest < ActionDispatch::IntegrationTest
  test "the owner shares into the current household, then stops" do
    goal = goals(:spouse_bible_reading)
    sign_in identities(:spouse)

    assert_difference -> { Goal::Sharing.count } do
      post sharing_path(goal)
    end
    assert_redirected_to household_goal_path(household_id: households(:home), id: goal)
    assert_equal "Shared with The Head Family.", flash[:notice]
    assert_equal [ households(:home) ], goal.shared_households

    assert_difference -> { Goal::Sharing.count }, -1 do
      delete sharing_path(goal)
    end
    assert_redirected_to household_goal_path(household_id: households(:home), id: goal)
    assert_equal "Stopped sharing with The Head Family.", flash[:notice]
    assert_empty goal.reload.shared_households
  end

  test "another member can't share or stop sharing someone else's goal (404)" do
    goal = goals(:spouse_bible_reading)
    sign_in identities(:head)

    assert_no_difference -> { Goal::Sharing.count } do
      post sharing_path(goal)
    end
    assert_response :not_found

    goal.share_with(households(:home))
    sign_in identities(:head) # a 404 doesn't keep the session

    assert_no_difference -> { Goal::Sharing.count } do
      delete sharing_path(goal)
    end
    assert_response :not_found
  end

  test "a family goal can't be shared (404)" do
    sign_in identities(:spouse)

    assert_no_difference -> { Goal::Sharing.count } do
      post sharing_path(goals(:gospels))
    end
    assert_response :not_found
  end

  private
    def sharing_path(goal, household = households(:home))
      household_goal_sharing_path(household_id: household, goal_id: goal)
    end
end
