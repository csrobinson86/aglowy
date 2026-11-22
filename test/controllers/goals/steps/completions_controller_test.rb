require "test_helper"

class Goals::Steps::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @goal = goals(:gospels)
    @eli = users(:eli)
    @sofia = users(:sofia)
  end

  test "an adult ticks an everyone step, and Sofia's part for her" do
    sign_in identities(:spouse)

    post completions_path(goal_steps(:read_luke)), params: { user_id: "" }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(goal_steps(:read_luke))}]"
    assert_select "turbo-stream[action=replace][method=morph][target=#{dom_id(goal_steps(:read_luke), :panel_body)}]"
    assert_select "turbo-stream[action=replace][target=goal-progress]"
    tick = goal_steps(:read_luke).completions.sole
    assert_nil tick.user
    assert_equal users(:spouse), tick.completed_by

    post completions_path(goal_steps(:parables)), params: { user_id: @sofia.id }, as: :turbo_stream

    assert_response :success
    tick = goal_steps(:parables).completions.find_by!(user: @sofia)
    assert_equal users(:spouse), tick.completed_by
    assert goal_steps(:parables).reload.done?
    assert_includes response.body, "5 of 7 steps done"
  end

  test "Eli ticks his part, then unticks it" do
    step = @goal.add_step(title: "Memorize John 3:16", assignees: [ @eli, @sofia ])
    sign_in eli_identity

    assert_difference -> { step.completions.count }, 1 do
      post completions_path(step), params: { user_id: @eli.id }, as: :turbo_stream
    end
    assert_response :success
    assert_select "button[autofocus]", count: 1, text: /Eli Child done/
    tick = step.completions.find_by!(user: @eli)
    assert_equal @eli, tick.completed_by

    assert_difference -> { step.completions.count }, -1 do
      delete completion_path(step, tick), as: :turbo_stream
    end
    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(step)}]"
    assert_select "button[autofocus]", count: 1, text: /Eli Child\s*\z/
  end

  test "Eli posting an everyone step is refused" do
    sign_in eli_identity

    assert_no_difference "Goal::Step::Completion.count" do
      post completions_path(goal_steps(:read_luke)), params: { user_id: "" }, as: :turbo_stream
    end
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]

    assert_no_difference "Goal::Step::Completion.count" do
      delete completion_path(goal_steps(:read_matthew), goal_step_completions(:read_matthew_together)), as: :turbo_stream
    end
    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "Eli posting with Sofia's user_id is refused" do
    sign_in eli_identity

    assert_no_difference "Goal::Step::Completion.count" do
      post completions_path(goal_steps(:parables)), params: { user_id: @sofia.id }, as: :turbo_stream
    end
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_not goal_steps(:parables).completions.exists?(user: @sofia)
  end

  test "ticking on an archived goal is refused" do
    @goal.archive(by: users(:spouse))
    sign_in identities(:spouse)

    assert_no_difference "Goal::Step::Completion.count" do
      post completions_path(goal_steps(:read_luke)), params: { user_id: "" }, as: :turbo_stream
    end
    assert_redirected_to household_root_path(household_id: households(:home))

    assert_no_difference "Goal::Step::Completion.count" do
      delete completion_path(goal_steps(:read_matthew), goal_step_completions(:read_matthew_together)), as: :turbo_stream
    end
    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "a step from another household's goal is 404" do
    sign_in identities(:spouse)
    assert_no_difference "Goal::Step::Completion.count" do
      post household_goal_step_completions_path(household_id: households(:home), goal_id: goals(:outsiders_reading), step_id: goal_steps(:read_acts)),
           params: { user_id: "" }, as: :turbo_stream
    end
    assert_response :not_found

    # Another household's step under this household's goal.
    sign_in identities(:spouse) # a 404 doesn't keep the session
    assert_no_difference "Goal::Step::Completion.count" do
      post completions_path(goal_steps(:read_acts)), params: { user_id: "" }, as: :turbo_stream
    end
    assert_response :not_found
  end

  test "a tick from a stale page redraws the step as it is now" do
    sign_in identities(:spouse)

    # The page still showed the parables step as an Everyone step, so its checkbox posts done together.
    assert_no_difference "Goal::Step::Completion.count" do
      post completions_path(goal_steps(:parables)), params: { user_id: "" }, as: :turbo_stream
    end
    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=#{dom_id(goal_steps(:parables))}]"
    assert_select "turbo-stream[action=replace][target=goal-progress]"
  end

  test "a person who isn't named on the step is 404" do
    sign_in identities(:spouse)

    assert_no_difference "Goal::Step::Completion.count" do
      post completions_path(goal_steps(:parables)), params: { user_id: users(:outsider).id }, as: :turbo_stream
    end
    assert_response :not_found
  end

  test "another step's tick is 404" do
    sign_in identities(:spouse)

    assert_no_difference "Goal::Step::Completion.count" do
      delete completion_path(goal_steps(:read_luke), goal_step_completions(:read_matthew_together)), as: :turbo_stream
    end
    assert_response :not_found
  end

  private
    # Eli is a child with a login (frame milestone-goal-child.png).
    def eli_identity
      identities(:eli)
    end

    def completions_path(step)
      household_goal_step_completions_path(household_id: households(:home), goal_id: @goal, step_id: step)
    end

    def completion_path(step, completion)
      household_goal_step_completion_path(household_id: households(:home), goal_id: @goal, step_id: step, id: completion)
    end

    def dom_id(...)
      ActionView::RecordIdentifier.dom_id(...)
    end
end
