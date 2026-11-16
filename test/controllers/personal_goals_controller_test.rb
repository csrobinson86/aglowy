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

  test "the Shared tab lists goals others shared here, with the owner's name, and not the person's own" do
    goals(:spouse_bible_reading).share_with(households(:home))
    head_goal = users(:head).goals.create!(title: "Read the Psalms", target_on: Date.new(2027, 2, 28), set_by: users(:head))
    head_goal.share_with(households(:home))
    users(:head).goals.create!(title: "Pray every morning", target_on: Date.new(2027, 2, 28), set_by: users(:head)).share_with(households(:parents))
    sign_in identities(:spouse)

    get household_my_goals_path(household_id: households(:home), status: "shared")

    assert_response :success
    assert_select "nav[aria-label='Goals'] a[aria-current='page']", text: /Shared in this household\s*1/
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row a[href='#{household_goal_path(household_id: households(:home), id: head_goal)}']", "Read the Psalms"
    assert_select "main .Box-row .Label", "Shared by Hannah Head"
  end

  # Steps stored in a different order from their positions, so a list that loses the steps' order shows it.
  test "a shared goal's row names its first undone step by position" do
    goal = goals(:spouse_bible_reading)
    later = goal.add_step(title: "Read Exodus")
    first = goal.add_step(title: "Read Genesis 1 to 25")
    later.update_column(:position, 2)
    first.update_column(:position, 1)
    goal.share_with(households(:home))
    sign_in identities(:head)

    get household_my_goals_path(household_id: households(:home), status: "shared")

    assert_select "main .Box-row", text: /Next: Read Genesis 1 to 25/
  end

  test "an empty Shared tab says so" do
    sign_in identities(:spouse)

    get household_my_goals_path(household_id: households(:home), status: "shared")

    assert_select "nav[aria-label='Goals'] a[aria-current='page']", text: /Shared in this household\s*0/
    assert_select ".blankslate h2", "Nothing shared here yet"
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

  test "?tag= lists only the person's goals with that tag, with a removable filter and each row's tags" do
    tagged = goals(:spouse_bible_reading)
    tagged.tag_with("ministry", by: users(:spouse))
    users(:spouse).goals.create!(title: "Pray every morning", target_on: Date.new(2027, 2, 28), set_by: users(:spouse))
    sign_in identities(:spouse)

    get household_my_goals_path(household_id: households(:home), tag: "ministry")

    assert_response :success
    assert_select "main a[href='#{household_my_goals_path(household_id: households(:home))}'][aria-label='Remove filter #ministry']"
    assert_select "nav[aria-label='Goals'] a[aria-current='page'][href*='tag=ministry']", text: /Active\s*1/
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row a.Label[href='#{household_tag_path(household_id: households(:home), name: "ministry")}']", text: "#ministry"

    get household_my_goals_path(household_id: households(:home), tag: "unknown")

    assert_select "main .Box-row", count: 0
    assert_select ".blankslate h2", "No goals tagged #unknown"
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
