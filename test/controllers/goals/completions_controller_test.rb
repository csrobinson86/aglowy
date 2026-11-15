require "test_helper"

class Goals::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup { @goal = goals(:gospels) }

  test "an adult completes a goal, then reopens it" do
    sign_in identities(:spouse)

    post completion_path(@goal)

    assert_redirected_to household_goal_path(household_id: households(:home), id: @goal)
    assert_equal "Goal marked complete.", flash[:notice]
    assert @goal.reload.completed?
    assert_equal users(:spouse), @goal.completion.completed_by

    delete completion_path(@goal)

    assert_redirected_to household_goal_path(household_id: households(:home), id: @goal)
    assert_equal "Goal reopened.", flash[:notice]
    assert_not @goal.reload.completed?
    assert_includes households(:home).goals.active, @goal
  end

  test "a child is refused completing and reopening" do
    sign_in child_identity

    post completion_path(@goal)
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_not @goal.reload.completed?

    delete completion_path(goals(:proverbs))
    assert_redirected_to household_root_path(household_id: households(:home))
    assert goals(:proverbs).reload.completed?
  end

  test "a goal from another household is 404" do
    sign_in identities(:spouse)
    post completion_path(goals(:outsiders_reading))
    assert_response :not_found
    assert_not goals(:outsiders_reading).reload.completed?

    sign_in identities(:spouse) # a 404 doesn't keep the session
    goals(:outsiders_reading).complete(by: users(:outsider))
    delete completion_path(goals(:outsiders_reading))
    assert_response :not_found
    assert goals(:outsiders_reading).reload.completed?
  end

  private
    def completion_path(goal)
      household_goal_completion_path(household_id: households(:home), goal_id: goal)
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
