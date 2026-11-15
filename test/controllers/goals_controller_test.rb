require "test_helper"

class GoalsControllerTest < ActionDispatch::IntegrationTest
  test "a child sees the list and no New goal button" do
    sign_in child_identity

    get household_goals_path(household_id: households(:home))

    assert_response :success
    assert_select "title", "Family goals · The Head Family · Aglowy"
    assert_select "h1", "Family goals"
    assert_select "main .Box-row", text: /Read the four Gospels together/
    assert_select "a", { text: "New goal", count: 0 }

    households(:home).goals.destroy_all
    get household_goals_path(household_id: households(:home))
    assert_select ".blankslate h2", "No family goals yet"
    assert_select "a", { text: "New goal", count: 0 }
  end

  test "a head and an adult see New goal, and on the empty Active tab" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity

      get household_goals_path(household_id: households(:home))
      assert_select "main a[href='#{new_household_goal_path(household_id: households(:home))}']", "New goal"
    end

    households(:home).goals.destroy_all
    get household_goals_path(household_id: households(:home))
    assert_select ".blankslate h2", "No family goals yet"
    assert_select ".blankslate a[href='#{new_household_goal_path(household_id: households(:home))}']", "New goal"
  end

  test "each tab lists its own goals, with the counts, and an unknown status falls back to Active" do
    sign_in identities(:spouse)

    get household_goals_path(household_id: households(:home), status: "nonsense")
    assert_select "nav[aria-label='Goals'] a[aria-current='page']", text: /Active\s*1/
    assert_select "nav[aria-label='Goals'] a", text: /Completed\s*1/
    assert_select "nav[aria-label='Goals'] a", text: /Archived\s*1/
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row", text: /Read the four Gospels together/

    get household_goals_path(household_id: households(:home), status: "completed")
    assert_select "nav[aria-label='Goals'] a[aria-current='page']", text: /Completed/
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row", text: /Read Proverbs together.*Marked complete by Sam Spouse/m

    get household_goals_path(household_id: households(:home), status: "archived")
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row", text: /Learn the new songs.*Archived by Sam Spouse/m
  end

  test "empty Completed and Archived tabs say so" do
    sign_in identities(:spouse)
    goals(:proverbs).destroy
    goals(:songs).destroy

    get household_goals_path(household_id: households(:home), status: "completed")
    assert_select ".blankslate h2", "Nothing completed yet"

    get household_goals_path(household_id: households(:home), status: "archived")
    assert_select ".blankslate h2", "Nothing archived"
  end

  test "seven goals run no more queries than one" do
    sign_in identities(:spouse)
    get household_goals_path(household_id: households(:home))
    one_goal = queries_for { get household_goals_path(household_id: households(:home)) }

    6.times do |n|
      goal = households(:home).goals.create!(title: "Goal #{n}", target_on: Date.new(2027, 1, n + 1), set_by: users(:spouse))
      goal.add_step(title: "For Eli", assignees: [ users(:eli) ]).tick(for: users(:eli), by: users(:spouse))
      goal.add_step(title: "Together")
    end
    seven_goals = queries_for { get household_goals_path(household_id: households(:home)) }

    assert_select "main .Box-row", count: 7
    assert_equal one_goal, seven_goals
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    get household_goals_path(household_id: households(:home))
    assert_response :not_found

    get new_household_goal_path(household_id: households(:home))
    assert_response :not_found

    assert_no_difference "Goal.count" do
      post household_goals_path(household_id: households(:home)), params: { goal: valid_params }
    end
    assert_response :not_found
  end

  test "a child posting create is refused" do
    sign_in child_identity

    get new_household_goal_path(household_id: households(:home))
    assert_redirected_to household_root_path(household_id: households(:home))

    assert_no_difference "Goal.count" do
      post household_goals_path(household_id: households(:home)), params: { goal: valid_params }
    end
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "an adult creates a goal" do
    sign_in identities(:spouse)

    get new_household_goal_path(household_id: households(:home))
    assert_response :success
    assert_select "title", "New family goal · The Head Family · Aglowy"
    assert_select "nav[aria-label='Breadcrumb'] a[href='#{household_goals_path(household_id: households(:home))}']", "Family goals"
    assert_select "input[type=date][name='goal[target_on]']"
    assert_text_on_page "You'll add the steps next, on the goal's page."

    assert_difference -> { households(:home).goals.count }, 1 do
      post household_goals_path(household_id: households(:home)), params: { goal: valid_params.merge(set_by_id: users(:head).id, user_id: users(:spouse).id) }
    end

    goal = Goal.order(:created_at).last
    assert_redirected_to household_goals_path(household_id: households(:home))
    assert_equal "Read Acts together", goal.title
    assert_equal "To see how the early Christians preached.", goal.body
    assert_equal Date.new(2027, 6, 30), goal.target_on
    assert_equal users(:spouse), goal.set_by
    assert goal.family?
    assert_not goal.personal?
    assert goal.milestone?
  end

  test "a blank title re-renders with the error on Title" do
    sign_in identities(:spouse)

    assert_no_difference "Goal.count" do
      post household_goals_path(household_id: households(:home)), params: { goal: valid_params.merge(title: "") }
    end

    assert_response :unprocessable_content
    title = css_select("input[name='goal[title]']").first
    assert_equal "true", title["aria-invalid"]
    assert_select "##{title["aria-describedby"].split.first}", text: /can't be blank/
    assert_select "textarea[name='goal[body]']", text: /To see how the early Christians preached./
  end

  private
    def valid_params
      { title: "Read Acts together", body: "To see how the early Christians preached.", target_on: "2027-06-30" }
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end

    def assert_text_on_page(text)
      assert_includes CGI.unescapeHTML(response.body), text
    end

    def queries_for(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
