require "test_helper"

class PersonalGoalsControllerTest < ActionDispatch::IntegrationTest
  test "a person sees only their own goals" do
    head_goal = users(:head).goals.create!(title: "Read the Psalms", target_on: Date.new(2027, 2, 28), set_by: users(:head))
    sign_in identities(:spouse)

    get household_my_goals_path(household_id: households(:home))

    assert_response :success
    assert_select "title", "My goals · The Head Family · Aglowy"
    assert_select "h1", "My goals"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "My goals"
    assert_select "nav[aria-label='Goals'] a[aria-current='page']", text: /Active\s*1/
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row a[href='#{household_goal_path(household_id: households(:home), id: goals(:spouse_bible_reading))}']", "Read the whole Bible in a year"
    assert_select "main", text: /Read the four Gospels together/, count: 0
    assert_select "main", text: /#{head_goal.title}/, count: 0
    assert_select "main a[href='#{new_household_my_goal_path(household_id: households(:home))}']", "New goal"
  end

  test "each tab lists the person's own goals, and an empty one says so" do
    goal = goals(:spouse_bible_reading)
    sign_in identities(:spouse)

    get household_my_goals_path(household_id: households(:home), status: "completed")
    assert_select ".blankslate h2", "Nothing completed yet"

    goal.complete(by: users(:spouse))
    get household_my_goals_path(household_id: households(:home), status: "completed")
    assert_select "main .Box-row", text: /Read the whole Bible in a year.*Marked complete by Sam Spouse/m

    goal.archive(by: users(:spouse))
    get household_my_goals_path(household_id: households(:home), status: "archived")
    assert_select "nav[aria-label='Goals'] a[aria-current='page']", text: /Archived\s*1/
    assert_select "main .Box-row", text: /Read the whole Bible in a year/

    get household_my_goals_path(household_id: households(:home))
    assert_select ".blankslate h2", "No goals of your own yet"
    assert_select ".blankslate a[href='#{new_household_my_goal_path(household_id: households(:home))}']", "New goal"
  end

  test "creates one" do
    sign_in identities(:spouse)

    get new_household_my_goal_path(household_id: households(:home))
    assert_response :success
    assert_select "title", "New goal · The Head Family · Aglowy"
    assert_select "nav[aria-label='Breadcrumb'] a[href='#{household_my_goals_path(household_id: households(:home))}']", "My goals"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "My goals"
    assert_select "form[action='#{household_my_goals_path(household_id: households(:home))}'] input[type=date][name='goal[target_on]']"
    assert_select ".FormControl-caption", "Shown at the top of the goal to remind you why."

    assert_difference -> { users(:spouse).goals.count }, 1 do
      post household_my_goals_path(household_id: households(:home)),
           params: { goal: valid_params.merge(household_id: households(:home).id, user_id: users(:head).id, set_by_id: users(:head).id) }
    end

    goal = Goal.order(:created_at).last
    assert_redirected_to household_goal_path(household_id: households(:home), id: goal)
    assert_equal "Goal created.", flash[:notice]
    assert_equal [ "Pioneer for a month", "To give more of my time.", Date.new(2027, 4, 30) ], [ goal.title, goal.body, goal.target_on ]
    assert_equal [ users(:spouse), users(:spouse) ], [ goal.user, goal.set_by ]
    assert goal.personal?
    assert_nil goal.household_id
  end

  test "a blank title re-renders with the error on Title" do
    sign_in identities(:spouse)

    assert_no_difference "Goal.count" do
      post household_my_goals_path(household_id: households(:home)), params: { goal: valid_params.merge(title: "") }
    end

    assert_response :unprocessable_content
    assert_select "input[name='goal[title]'][aria-invalid='true']"
  end

  test "a child with a login creates and ticks their own" do
    sign_in identities(:eli)

    post household_my_goals_path(household_id: households(:home)), params: { goal: valid_params.merge(title: "Read my Bible story book") }
    goal = users(:eli).goals.sole
    assert_redirected_to household_goal_path(household_id: households(:home), id: goal)
    assert_equal users(:eli), goal.set_by

    post household_goal_steps_path(household_id: households(:home), goal_id: goal), params: { goal_step: { title: "Read story 1" } }, as: :turbo_stream
    assert_response :success
    step = goal.steps.sole

    post household_goal_step_completions_path(household_id: households(:home), goal_id: goal, step_id: step), as: :turbo_stream
    assert_response :success
    assert step.reload.done?
    assert_equal [ [ nil, users(:eli).id ] ], step.completions.pluck(:user_id, :completed_by_id)

    delete household_goal_step_completion_path(household_id: households(:home), goal_id: goal, step_id: step, id: step.completions.sole), as: :turbo_stream
    assert_response :success
    assert_not step.reload.done?
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)
    get household_my_goals_path(household_id: households(:home))
    assert_response :not_found

    sign_in identities(:outsider)
    assert_no_difference "Goal.count" do
      post household_my_goals_path(household_id: households(:home)), params: { goal: valid_params }
    end
    assert_response :not_found
  end

  private
    def valid_params
      { title: "Pioneer for a month", body: "To give more of my time.", target_on: "2027-04-30" }
    end
end
