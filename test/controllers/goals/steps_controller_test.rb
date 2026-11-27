require "test_helper"

class Goals::StepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @goal = goals(:gospels)
    @eli = users(:eli)
    @sofia = users(:sofia)
  end

  test "an adult adds a step for Eli and Sofia" do
    sign_in identities(:spouse)

    assert_difference -> { @goal.steps.count }, 1 do
      post steps_path, params: { goal_step: { title: "Memorize John 3:16", due_on: "2027-03-01", assignee_ids: [ "", @eli.id, @sofia.id ] } }, as: :turbo_stream
    end

    assert_response :success
    step = @goal.steps.last
    assert_equal [ "Memorize John 3:16", Date.new(2027, 3, 1), 8 ], [ step.title, step.due_on, step.position ]
    assert_equal [ @eli, @sofia ].sort_by(&:id), step.assignees.sort_by(&:id)
    assert_select "turbo-stream[action=replace][target=goal-steps]"
    assert_select "turbo-stream[action=replace][target=goal-progress]"
    assert_includes response.body, "Memorize John 3:16"
  end

  test "a step for everyone with no due date" do
    sign_in identities(:head)

    post steps_path, params: { goal_step: { title: "Sing a song about Jesus", due_on: "", assignee_ids: [ "" ] } }, as: :turbo_stream

    step = @goal.steps.last
    assert_equal "Sing a song about Jesus", step.title
    assert_nil step.due_on
    assert step.everyone?
  end

  test "a blank title re-renders the add-step row with the error" do
    sign_in identities(:spouse)

    assert_no_difference "Goal::Step.count" do
      post steps_path, params: { goal_step: { title: "", assignee_ids: [ @eli.id ] } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=new-goal-step]"
    assert_includes response.body, "can&#39;t be blank"
  end

  test "edits it to Everyone, which clears the per-person ticks" do
    step = goal_steps(:parables)
    sign_in identities(:spouse)

    patch step_path(step), params: { goal_step: { title: "Find a parable", due_on: "2027-03-01", assignee_ids: [ "" ], lock_version: 0 } }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace][target=goal-steps]"
    assert_select "turbo-stream[action=replace][target=goal-progress]"
    step.reload
    assert_equal [ "Find a parable", Date.new(2027, 3, 1) ], [ step.title, step.due_on ]
    assert step.everyone?
    assert_empty step.completions
    assert_equal 1, step.lock_version
  end

  test "changing only who a step is for still moves its lock_version on" do
    step = goal_steps(:read_luke)
    sign_in identities(:spouse)

    patch step_path(step), params: { goal_step: { title: step.title, due_on: "2027-02-15", assignee_ids: [ @eli.id ], lock_version: 0 } }, as: :turbo_stream

    step.reload
    assert_equal [ @eli ], step.assignees
    assert_equal 1, step.lock_version
  end

  test "a blank title on an edit re-renders the step's frame with the error and the people ticked, and changes nothing" do
    step = goal_steps(:parables)
    sign_in identities(:spouse)

    patch step_path(step), params: { goal_step: { title: "", assignee_ids: [ "", @sofia.id ], lock_version: 0 } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target='#{dom_id(step)}']"
    assert_includes response.body, "can&#39;t be blank"
    assert_select "turbo-stream[target='#{dom_id(step)}'] input[type=checkbox][value='#{@sofia.id}'][checked]", count: 1
    assert_select "turbo-stream[target='#{dom_id(step)}'] input[type=checkbox][value='#{@eli.id}'][checked]", count: 0
    # The phone panel, which didn't send it, shows the step and not the form (docs/design/phone.md, A goal).
    assert_select "turbo-stream[action=replace][method=morph][target='#{dom_id(step, :panel_body)}'] [data-goal-step-target=form][hidden]"
    assert_equal 2, step.reload.assignees.count
    assert_equal 1, step.completions.count
  end

  test "a blank title from the phone panel shows the form again in the panel only, morphed so it stays open" do
    step = goal_steps(:parables)
    sign_in identities(:spouse)

    patch step_path(step, panel: true), params: { goal_step: { title: "", assignee_ids: [ "", @sofia.id ], lock_version: 0 } }, as: :turbo_stream

    assert_response :unprocessable_content
    panel = "turbo-stream[action=replace][method=morph][target='#{dom_id(step, :panel_body)}']"
    assert_select "#{panel} [data-goal-step-target=form]:not([hidden])", text: /can't be blank/
    assert_select "#{panel} input[type=checkbox][value='#{@sofia.id}'][checked]", count: 1
    assert_select "#{panel} input[type=checkbox][value='#{@eli.id}'][checked]", count: 0
    assert_select "#{panel} form[action$='?panel=true']"
    assert_select "turbo-stream[target='#{dom_id(step)}'] [data-goal-step-target=form][hidden]"
    # The row and the panel's title show the step as saved, not the refused title.
    assert_select "turbo-stream[target='#{dom_id(step)}'] .goal-step__title", text: "Find three parables and explain one"
    assert_select "turbo-stream[action=update][target='#{dom_id(step, :panel)}-title']", text: "Find three parables and explain one"
    assert_equal "Find three parables and explain one", step.reload.title
  end

  test "a stale edit shows the form again with the step as it is now, and the panel's title follows" do
    step = goal_steps(:parables)
    step.update!(title: "Find two parables")
    sign_in identities(:spouse)

    patch step_path(step, panel: true), params: { goal_step: { title: "Find four parables", assignee_ids: [ "" ], lock_version: 0 } }, as: :turbo_stream

    assert_response :conflict
    panel = "turbo-stream[action=replace][method=morph][target='#{dom_id(step, :panel_body)}']"
    assert_select "#{panel} input[name='goal_step[title]'][value='Find two parables']"
    assert_select "turbo-stream[target='#{dom_id(step)}'] .goal-step__title", text: "Find two parables"
    assert_select "turbo-stream[action=update][target='#{dom_id(step, :panel)}-title']", text: "Find two parables"
    assert_equal "Find two parables", step.reload.title
  end

  # turbo-rails marks a String html_safe. The controller escapes the title, and config/initializers/turbo_streams.rb
  # escapes any String, so another adult's title reaches the panel's title as text (#451).
  test "an HTML title comes back as text in the panel's title when an edit is invalid" do
    step = goal_steps(:parables)
    step.update!(title: "<img src=x onerror=alert(1)>")
    sign_in identities(:spouse)

    patch step_path(step), params: { goal_step: { title: "", assignee_ids: [ "" ], lock_version: step.lock_version } }, as: :turbo_stream

    assert_turbo_stream(status: :unprocessable_content, action: :update, target: "#{dom_id(step, :panel)}-title") do
      assert_select "template img", count: 0
      assert_select "template", text: "<img src=x onerror=alert(1)>"
    end
  end

  test "an HTML title comes back as text in the panel's title when an edit is stale" do
    step = goal_steps(:parables)
    step.update!(title: "<img src=x onerror=alert(1)>")
    sign_in identities(:spouse)

    patch step_path(step), params: { goal_step: { title: "Find four parables", assignee_ids: [ "" ], lock_version: 0 } }, as: :turbo_stream

    assert_turbo_stream(status: :conflict, action: :update, target: "#{dom_id(step, :panel)}-title") do
      assert_select "template img", count: 0
      assert_select "template", text: "<img src=x onerror=alert(1)>"
    end
  end

  test "removes it" do
    step = goal_steps(:parables)
    sign_in identities(:spouse)

    assert_difference -> { @goal.steps.count }, -1 do
      delete step_path(step), as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=goal-steps]"
    assert_select "turbo-stream[action=replace][target=goal-progress]"
    assert_not Goal::Step::Completion.exists?(step_id: step.id)
  end

  test "a child is refused" do
    step = goal_steps(:parables)
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)

    assert_no_difference "Goal::Step.count" do
      post steps_path, params: { goal_step: { title: "Mine", assignee_ids: [ "" ] } }, as: :turbo_stream
    end
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]

    patch step_path(step), params: { goal_step: { title: "Mine", assignee_ids: [ "" ], lock_version: 0 } }, as: :turbo_stream
    assert_redirected_to household_root_path(household_id: households(:home))

    assert_no_difference "Goal::Step.count" do
      delete step_path(step), as: :turbo_stream
    end
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "Find three parables and explain one", step.reload.title
  end

  test "a finished goal takes no step changes" do
    goal = goals(:songs)
    sign_in identities(:spouse)

    assert_no_difference "Goal::Step.count" do
      post household_goal_steps_path(household_id: households(:home), goal_id: goal), params: { goal_step: { title: "One more", assignee_ids: [ "" ] } }, as: :turbo_stream
    end
    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "assigning someone from another household is invalid" do
    outsider = users(:outsider)
    sign_in identities(:spouse)

    assert_no_difference "Goal::Step.count" do
      post steps_path, params: { goal_step: { title: "Visit Olive", assignee_ids: [ outsider.id ] } }, as: :turbo_stream
    end
    assert_response :unprocessable_content
    assert_includes response.body, "Choose people in this household"

    step = goal_steps(:parables)
    patch step_path(step), params: { goal_step: { title: step.title, assignee_ids: [ @eli.id, outsider.id ], lock_version: 0 } }, as: :turbo_stream
    assert_response :unprocessable_content
    assert_includes response.body, "Choose people in this household"
    step.reload
    assert_equal [ @eli, @sofia ].sort_by(&:id), step.assignees.sort_by(&:id)
    assert_equal 0, step.lock_version
  end

  test "posting assignees on a personal goal's step is invalid" do
    goal = goals(:spouse_bible_reading)
    step = goal.add_step(title: "Read Genesis")
    sign_in identities(:spouse)

    assert_no_difference -> { Goal::Step.count } => 0, -> { Goal::Step::Assignment.count } => 0 do
      post household_goal_steps_path(household_id: households(:home), goal_id: goal),
           params: { goal_step: { title: "Read Exodus with Sam", assignee_ids: [ users(:spouse).id ] } }, as: :turbo_stream
    end
    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=new-goal-step]"

    patch household_goal_step_path(household_id: households(:home), goal_id: goal, id: step),
          params: { goal_step: { title: "Read Genesis", assignee_ids: [ users(:spouse).id ], lock_version: 0 } }, as: :turbo_stream
    assert_response :unprocessable_content
    assert step.reload.everyone?
    assert_equal 0, step.lock_version
  end

  test "the owner adds, edits and removes a personal goal's steps" do
    goal = goals(:spouse_bible_reading)
    sign_in identities(:spouse)

    post household_goal_steps_path(household_id: households(:home), goal_id: goal), params: { goal_step: { title: "Read Genesis", due_on: "2026-12-31" } }, as: :turbo_stream
    assert_response :success
    step = goal.steps.sole
    assert_equal [ "Read Genesis", Date.new(2026, 12, 31) ], [ step.title, step.due_on ]

    patch household_goal_step_path(household_id: households(:home), goal_id: goal, id: step),
          params: { goal_step: { title: "Read Genesis and Exodus", due_on: "", lock_version: 0 } }, as: :turbo_stream
    assert_response :success
    assert_equal [ "Read Genesis and Exodus", nil ], [ step.reload.title, step.due_on ]

    delete household_goal_step_path(household_id: households(:home), goal_id: goal, id: step), as: :turbo_stream
    assert_response :success
    assert_empty goal.steps.reload
  end

  test "a step on another household's goal is 404" do
    sign_in identities(:spouse)
    post household_goal_steps_path(household_id: households(:home), goal_id: goals(:outsiders_reading)), params: { goal_step: { title: "Mine" } }, as: :turbo_stream
    assert_response :not_found

    sign_in identities(:spouse) # a 404 doesn't keep the session
    patch household_goal_step_path(household_id: households(:home), goal_id: goals(:outsiders_reading), id: goal_steps(:read_acts)),
          params: { goal_step: { title: "Mine", lock_version: 0 } }, as: :turbo_stream
    assert_response :not_found

    # Another household's step under this household's goal.
    sign_in identities(:spouse)
    assert_no_difference "Goal::Step.count" do
      delete household_goal_step_path(household_id: households(:home), goal_id: @goal, id: goal_steps(:read_acts)), as: :turbo_stream
    end
    assert_response :not_found
    assert_equal "Read Acts chapter 1", goal_steps(:read_acts).reload.title
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    assert_no_difference "Goal::Step.count" do
      delete step_path(goal_steps(:parables)), as: :turbo_stream
    end
    assert_response :not_found
  end

  private
    def steps_path
      household_goal_steps_path(household_id: households(:home), goal_id: @goal)
    end

    def step_path(step, **)
      household_goal_step_path(household_id: households(:home), goal_id: @goal, id: step, **)
    end

    def dom_id(...)
      ActionView::RecordIdentifier.dom_id(...)
    end
end
