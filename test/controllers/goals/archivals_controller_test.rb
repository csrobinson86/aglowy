require "test_helper"

class Goals::ArchivalsControllerTest < ActionDispatch::IntegrationTest
  setup { @goal = goals(:gospels) }

  test "an adult archives a goal, then restores it to Active" do
    sign_in identities(:spouse)

    post archival_path(@goal)

    assert_redirected_to household_goals_path(household_id: households(:home), status: "archived")
    assert_equal "Goal archived.", flash[:notice]
    assert @goal.reload.archived?
    assert_equal users(:spouse), @goal.archival.archived_by

    delete archival_path(@goal)

    assert_redirected_to household_goal_path(household_id: households(:home), id: @goal)
    assert_equal "Goal restored.", flash[:notice]
    assert_not @goal.reload.archived?
    assert_includes households(:home).goals.active, @goal
  end

  test "restoring an archived, completed goal returns it to Completed" do
    sign_in identities(:head)
    goal = goals(:proverbs)

    post archival_path(goal)
    assert_includes households(:home).goals.archived, goal

    delete archival_path(goal)
    assert_includes households(:home).goals.completed, goal
    assert goal.reload.completed?
  end

  test "a child is refused archiving and restoring" do
    sign_in child_identity

    post archival_path(@goal)
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_not @goal.reload.archived?

    delete archival_path(goals(:songs))
    assert_redirected_to household_root_path(household_id: households(:home))
    assert goals(:songs).reload.archived?
  end

  test "a goal from another household is 404" do
    sign_in identities(:spouse)
    post archival_path(goals(:outsiders_reading))
    assert_response :not_found
    assert_not goals(:outsiders_reading).reload.archived?

    sign_in identities(:spouse) # a 404 doesn't keep the session
    goals(:outsiders_reading).archive(by: users(:outsider))
    delete archival_path(goals(:outsiders_reading))
    assert_response :not_found
    assert goals(:outsiders_reading).reload.archived?
  end

  private
    def archival_path(goal)
      household_goal_archival_path(household_id: households(:home), goal_id: goal)
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
