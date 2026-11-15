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

    sign_in identities(:outsider)
    get new_household_goal_path(household_id: households(:home))
    assert_response :not_found

    sign_in identities(:outsider)
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
    assert_redirected_to household_goal_path(household_id: households(:home), id: goal)
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

  test "every member can show a family goal" do
    [ identities(:head), identities(:spouse), child_identity ].each do |identity|
      sign_in identity

      get goal_path(goals(:gospels))

      assert_response :success
      assert_select "title", "Read the four Gospels together · The Head Family · Aglowy"
      assert_select "nav[aria-label='Breadcrumb'] a[href='#{household_goals_path(household_id: households(:home))}']", "Family goals"
      assert_select "h1", /\ARead the four Gospels together\s*Milestone\z/
      assert_select "h1 .Label", "Milestone"
      assert_text_on_page "Target March 31, 2027 · Set by Sam Spouse"
      assert_text_on_page "So we get to know Jesus better as a family."
      assert_select "#goal-progress", text: /3 of 7 steps done/
      assert_select "#goal-progress", text: /4 to go · next due Feb 15/
      assert_select "#goal-progress .Progress"
      assert_select "#goal-progress li", text: /Eli Child · 4 of 6/
      assert_select "#goal-progress li", text: /Sofia Child · 2 of 5/
      assert_select "#goal-steps .Box-row", count: 7
      assert_select "nav[aria-label='Main'] a[aria-current='page']", "Family goals"
    end
  end

  test "heads and adults get Edit and the add-step row; a child gets neither" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get goal_path(goals(:gospels))
      assert_select "main a[href='#{edit_goal_path(goals(:gospels))}']", "Edit"
      assert_select "form[action='#{household_goal_steps_path(household_id: households(:home), goal_id: goals(:gospels))}']"
    end

    sign_in child_identity
    get goal_path(goals(:gospels))
    assert_select "a", { text: "Edit", count: 0 }
    assert_select "button[aria-label^='Edit step']", count: 0
    assert_select "form[action='#{household_goal_steps_path(household_id: households(:home), goal_id: goals(:gospels))}']", count: 0
    assert_select "form[method=post][action*='/steps/']", count: 0
  end

  test "a goal with seven more steps runs no more queries" do
    sign_in identities(:spouse)
    goal = goals(:proverbs)
    goal.completion.destroy
    goal.add_step(title: "Read chapter 1", assignees: [ users(:eli) ])
    get goal_path(goal)
    one_step = queries_for { get goal_path(goal) }

    7.times { goal.add_step(title: "Read chapter #{it + 2}", assignees: [ users(:eli), users(:sofia) ]).tick(for: users(:eli), by: users(:spouse)) }
    eight_steps = queries_for { get goal_path(goal) }

    assert_select "#goal-steps .Box-row", count: 8
    assert_equal one_step, eight_steps
  end

  test "a non-member gets 404, and so does a goal from another household" do
    sign_in identities(:outsider)
    get goal_path(goals(:gospels))
    assert_response :not_found

    sign_in identities(:spouse) # a 404 doesn't keep the session
    get household_goal_path(household_id: households(:home), id: goals(:outsiders_reading))
    assert_response :not_found

    sign_in identities(:spouse)
    patch household_goal_path(household_id: households(:home), id: goals(:outsiders_reading)), params: { goal: { title: "Mine now", lock_version: 0 } }
    assert_response :not_found
    assert_equal "Read Acts together", goals(:outsiders_reading).reload.title
  end

  test "another member of the same household gets 404 on someone's personal goal" do
    goal = goals(:spouse_bible_reading)
    step = goal.add_step(title: "Read Genesis")

    [ identities(:head), identities(:eli) ].each do |identity|
      sign_in identity
      get household_goal_path(household_id: households(:home), id: goal)
      assert_response :not_found

      sign_in identity # a 404 doesn't keep the session
      get edit_household_goal_path(household_id: households(:home), id: goal)
      assert_response :not_found

      sign_in identity
      patch household_goal_path(household_id: households(:home), id: goal), params: { goal: { title: "Mine now", lock_version: 0 } }
      assert_response :not_found

      sign_in identity
      post household_goal_archival_path(household_id: households(:home), goal_id: goal)
      assert_response :not_found

      sign_in identity
      post household_goal_step_completions_path(household_id: households(:home), goal_id: goal, step_id: step), as: :turbo_stream
      assert_response :not_found

      sign_in identity
      delete household_goal_path(household_id: households(:home), id: goal)
      assert_response :not_found
    end

    assert_equal "Read the whole Bible in a year", goal.reload.title
    assert goal.open?
    assert_not step.reload.done?
  end

  test "the owner sees it from either of their households" do
    goal = users(:head).goals.create!(title: "Read the Psalms", body: "To pray better.", target_on: Date.new(2027, 2, 28), set_by: users(:head))
    goal.add_step(title: "Read Psalms 1 to 50", due_on: Date.new(2026, 12, 31))
    sign_in identities(:head)

    [ households(:home), households(:parents) ].each do |household|
      get household_goal_path(household_id: household, id: goal)

      assert_response :success
      assert_select "title", "Read the Psalms · #{household.name} · Aglowy"
      assert_select "nav[aria-label='Breadcrumb'] a[href='#{household_my_goals_path(household_id: household)}']", "My goals"
      assert_select "nav[aria-label='Main'] a[aria-current='page']", "My goals"
      assert_select "h1 .Label", "Milestone"
      assert_select "h1 .Label", "Private"
      assert_text_on_page "Target February 28, 2027"
      assert_not_includes response.body, "Set by"
      assert_text_on_page "To pray better."
      assert_select "#goal-progress", text: /0 of 1 step done/
      assert_select "#goal-progress li", count: 0
      assert_select "#goal-steps .Box-row", text: /Read Psalms 1 to 50\s*Due Dec 31/
      assert_select "#goal-steps .avatar", count: 0
      assert_select "#goal-steps form[action='#{household_goal_step_completions_path(household_id: household, goal_id: goal, step_id: goal.steps.sole)}']"
      assert_select "#goal-steps input[name='goal_step[assignee_ids][]']", count: 0
      assert_select "a", { text: "Schedule as a family study", count: 0 }
      assert_select "action-menu form[action='#{household_goal_completion_path(household_id: household, goal_id: goal)}']", text: /Mark goal complete/
      assert_select "dialog#delete-goal form[action='#{household_goal_path(household_id: household, id: goal)}']"

      get edit_household_goal_path(household_id: household, id: goal)
      assert_select "nav[aria-label='Breadcrumb'] a[href='#{household_my_goals_path(household_id: household)}']", "My goals"
      assert_select "nav[aria-label='Main'] a[aria-current='page']", "My goals"
    end
  end

  test "a member reads a shared goal: Shared by its owner, progress and steps, and no controls" do
    goal = goals(:spouse_bible_reading)
    goal.add_step(title: "Read Genesis", due_on: Date.new(2026, 12, 31))
    goal.steps.sole.tick(for: nil, by: users(:spouse))
    goal.add_step(title: "Read Exodus")
    goal.share_with(households(:home))

    [ identities(:head), identities(:eli) ].each do |identity|
      sign_in identity
      get household_goal_path(household_id: households(:home), id: goal)

      assert_response :success
      assert_select "h1", /Read the whole Bible in a year/
      assert_select "h1 .Label", "Shared by Sam Spouse"
      assert_select "h1 .Label", { text: "Private", count: 0 }
      assert_select "nav[aria-label='Breadcrumb'] a[href=?]", household_my_goals_path(household_id: households(:home), status: "shared"), text: "My goals"
      assert_select "#goal-progress", text: /1 of 2 steps done/
      assert_select "#goal-steps .Box-row", count: 2
      assert_select "#goal-steps .Box-row", text: /Read Genesis\s*Done · /
      assert_select "main form", count: 0
      assert_select "main input, main button, main action-menu, main dialog", count: 0
      assert_select "a[href='#{edit_household_goal_path(household_id: households(:home), id: goal)}']", count: 0
    end
  end

  test "a member gets 404 on a shared goal's edit page, and on changing it" do
    goal = goals(:spouse_bible_reading)
    goal.share_with(households(:home))
    sign_in identities(:head)

    get edit_household_goal_path(household_id: households(:home), id: goal)
    assert_response :not_found

    sign_in identities(:head) # a 404 doesn't keep the session
    patch household_goal_path(household_id: households(:home), id: goal), params: { goal: { title: "Mine now", lock_version: 0 } }
    assert_response :not_found

    sign_in identities(:head)
    post household_goal_completion_path(household_id: households(:home), goal_id: goal)
    assert_response :not_found

    sign_in identities(:head)
    post household_goal_archival_path(household_id: households(:home), goal_id: goal)
    assert_response :not_found

    sign_in identities(:head)
    post household_goal_steps_path(household_id: households(:home), goal_id: goal), params: { goal_step: { title: "Mine now" } }, as: :turbo_stream
    assert_response :not_found

    sign_in identities(:head)
    delete household_goal_path(household_id: households(:home), id: goal)
    assert_response :not_found

    assert_equal "Read the whole Bible in a year", goal.reload.title
    assert goal.open?
    assert_empty goal.steps
  end

  test "ticking a shared goal's steps is refused (404)" do
    goal = goals(:spouse_bible_reading)
    step = goal.add_step(title: "Read Genesis")
    done_step = goal.add_step(title: "Read Exodus")
    tick = done_step.tick(for: nil, by: users(:spouse))
    goal.share_with(households(:home))

    sign_in identities(:head)
    post household_goal_step_completions_path(household_id: households(:home), goal_id: goal, step_id: step), as: :turbo_stream
    assert_response :not_found

    sign_in identities(:head)
    delete household_goal_step_completion_path(household_id: households(:home), goal_id: goal, step_id: done_step, id: tick), as: :turbo_stream
    assert_response :not_found

    assert_not step.reload.done?
    assert done_step.reload.done?
  end

  test "a goal shared into another household is still a 404 here" do
    goal = users(:head).goals.create!(title: "Read the Psalms", target_on: Date.new(2027, 2, 28), set_by: users(:head))
    goal.share_with(households(:parents))
    sign_in identities(:spouse)

    get household_goal_path(household_id: households(:home), id: goal)
    assert_response :not_found
  end

  test "the owner's page shows who it's shared with and Stop sharing; a private one has Share with household" do
    goal = goals(:spouse_bible_reading)
    sign_in identities(:spouse)

    get household_goal_path(household_id: households(:home), id: goal)
    assert_select "h1 .Label", "Private"
    assert_select "dialog#share-goal", text: /Members of The Head Family will be able to read this goal and its steps. They can't change it./
    assert_select "dialog#share-goal form[action='#{household_goal_sharing_path(household_id: households(:home), goal_id: goal)}']"

    goal.share_with(households(:home))
    get household_goal_path(household_id: households(:home), id: goal)
    assert_select "h1 .Label", "Shared with The Head Family"
    assert_select "dialog#share-goal", count: 0
    assert_select "form[action='#{household_goal_sharing_path(household_id: households(:home), goal_id: goal)}'] input[name=_method][value=delete]"
  end

  test "a family goal has no sharing controls" do
    sign_in identities(:spouse)

    get goal_path(goals(:gospels))

    assert_select "dialog#share-goal", count: 0
    assert_select "h1 .Label", { text: /Private|Shared/, count: 0 }
  end

  test "archiving or deleting a personal goal goes back to My goals" do
    goal = goals(:spouse_bible_reading)
    sign_in identities(:spouse)

    post household_goal_archival_path(household_id: households(:home), goal_id: goal)
    assert_redirected_to household_my_goals_path(household_id: households(:home), status: "archived")
    assert goal.reload.archived?

    delete household_goal_path(household_id: households(:home), id: goal)
    assert_redirected_to household_my_goals_path(household_id: households(:home))
    assert_not Goal.exists?(goal.id)
  end

  test "a child can't edit: 404 on edit, refused on update" do
    child = child_identity
    sign_in child
    get edit_goal_path(goals(:gospels))
    assert_response :not_found

    sign_in child # a 404 doesn't keep the session
    patch goal_path(goals(:gospels)), params: { goal: { title: "Mine now", lock_version: goals(:gospels).lock_version } }
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_equal "Read the four Gospels together", goals(:gospels).reload.title
  end

  test "an adult edits a goal" do
    sign_in identities(:spouse)
    goal = goals(:gospels)

    get edit_goal_path(goal)
    assert_response :success
    assert_select "title", "Edit goal · The Head Family · Aglowy"
    assert_select "nav[aria-label='Breadcrumb'] a[href='#{goal_path(goal)}']", "Read the four Gospels together"
    assert_select "input[name='goal[title]'][value='Read the four Gospels together']"
    assert_select "input[type=hidden][name='goal[lock_version]'][value='0']"
    assert_select "input[type=date][name='goal[target_on]'][value='2027-03-31']"

    patch goal_path(goal), params: { goal: { title: "Read the Gospels", body: "Before the Memorial.", target_on: "2027-04-01", lock_version: 0 } }

    assert_redirected_to goal_path(goal)
    assert_equal "Goal updated.", flash[:notice]
    goal.reload
    assert_equal [ "Read the Gospels", "Before the Memorial.", Date.new(2027, 4, 1) ], [ goal.title, goal.body, goal.target_on ]
    assert_equal users(:spouse), goal.set_by
  end

  test "a blank title re-renders the edit page with the error" do
    sign_in identities(:spouse)

    patch goal_path(goals(:gospels)), params: { goal: { title: "", lock_version: 0 } }

    assert_response :unprocessable_content
    assert_select "input[name='goal[title]'][aria-invalid='true']"
    assert_equal "Read the four Gospels together", goals(:gospels).reload.title
  end

  test "a stale lock_version re-renders with the message and the fresh values" do
    goals(:gospels).update!(title: "Read the Gospels, changed by Hannah")
    sign_in identities(:spouse)

    patch goal_path(goals(:gospels)), params: { goal: { title: "Sam's title", target_on: "2027-04-01", lock_version: 0 } }

    assert_response :conflict
    assert_select ".flash", text: /Someone else changed this goal. Here's the latest./
    assert_select "input[name='goal[title]'][value='Read the Gospels, changed by Hannah']"
    assert_select "input[type=hidden][name='goal[lock_version]'][value='1']"
    assert_equal "Read the Gospels, changed by Hannah", goals(:gospels).reload.title
    assert_equal Date.new(2027, 3, 31), goals(:gospels).target_on
  end

  test "a stale step edit changes nothing and keeps the ticks" do
    step = goal_steps(:parables)
    step.touch # someone else saved it first
    sign_in identities(:spouse)

    patch household_goal_step_path(household_id: households(:home), goal_id: goals(:gospels), id: step),
          params: { goal_step: { title: "Find one parable", assignee_ids: [ "" ], lock_version: 0 } }, as: :turbo_stream

    assert_response :conflict
    assert_select "turbo-stream[action=replace][target='#{ActionView::RecordIdentifier.dom_id(step)}']"
    assert_includes response.body, "Someone else changed this step. Here&#39;s the latest."
    step.reload
    assert_equal "Find three parables and explain one", step.title
    assert_equal [ users(:eli), users(:sofia) ].sort_by(&:id), step.assignees.sort_by(&:id)
    assert_equal [ users(:eli).id ], step.completions.map(&:user_id)
  end

  test "an adult deletes a goal and its steps go with it" do
    sign_in identities(:spouse)
    goal = goals(:gospels)
    step_ids = goal.steps.ids

    assert_difference -> { Goal.count } => -1, -> { Goal::Step.count } => -step_ids.size do
      delete goal_path(goal)
    end

    assert_redirected_to household_goals_path(household_id: households(:home))
    assert_equal "Goal deleted.", flash[:notice]
    assert_not Goal.exists?(goal.id)
    assert_empty Goal::Step.where(id: step_ids)
    assert_empty Goal::Step::Completion.where(step_id: step_ids)
    assert_empty Goal::Step::Assignment.where(step_id: step_ids)
  end

  test "a child is refused deleting a goal" do
    sign_in child_identity

    assert_no_difference "Goal.count" do
      delete goal_path(goals(:gospels))
    end

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "deleting a goal from another household is 404" do
    sign_in identities(:spouse)

    assert_no_difference "Goal.count" do
      delete household_goal_path(household_id: households(:home), id: goals(:outsiders_reading))
    end

    assert_response :not_found
  end

  test "heads and adults get the goal menu and the delete dialog; a child gets neither" do
    sign_in identities(:spouse)
    get goal_path(goals(:gospels))
    assert_select "action-menu button[aria-label='Goal actions']"
    assert_select "action-menu form[action='#{completion_path(goals(:gospels))}']", text: /Mark goal complete/
    assert_select "action-menu form[action='#{archival_path(goals(:gospels))}']", text: /Archive/
    assert_select "action-menu [data-show-dialog-id='delete-goal']", text: /Delete goal…/
    assert_select "dialog#delete-goal", text: /Delete this goal\?.*Its steps and progress are deleted too. Archive it instead to keep it for looking back./m
    assert_select "dialog#delete-goal form[action='#{goal_path(goals(:gospels))}'] input[name=_method][value=delete]"
    assert_select "dialog#delete-goal button", text: "Cancel"

    sign_in child_identity
    get goal_path(goals(:gospels))
    assert_select "button[aria-label='Goal actions']", count: 0
    assert_select "dialog#delete-goal", count: 0
  end

  test "the Every step is done Banner has the Mark goal complete button" do
    sign_in identities(:spouse)
    goal = households(:home).goals.create!(title: "Read Jonah", target_on: Date.new(2027, 1, 31), set_by: users(:spouse))
    goal.add_step(title: "Read Jonah 1").tick(for: nil, by: users(:spouse))

    get goal_path(goal)

    assert_select ".Banner", text: /Every step is done. Mark the goal complete\?/ do
      assert_select "form[action='#{completion_path(goal)}'] button", "Mark goal complete"
    end
  end

  test "a completed goal shows who completed it, Reopen, and no ticking or step editing" do
    travel_to Time.utc(2026, 11, 14, 12)
    sign_in identities(:spouse)
    goal = goals(:proverbs)
    goal.steps.create!(title: "Read Proverbs 1", position: 1) # a finished goal takes no new steps through add_step

    get goal_path(goal)

    assert_select ".Banner", text: /Completed on October 30 by Sam Spouse\./ do
      assert_select "form[action='#{completion_path(goal)}'] input[name=_method][value=delete]"
      assert_select "button", "Reopen goal"
    end
    assert_select "action-menu form[action='#{completion_path(goal)}']", text: /Reopen goal/
    assert_select "action-menu form[action='#{archival_path(goal)}']", text: /Archive/
    assert_no_ticking_or_step_editing(goal)
  end

  test "an archived goal shows who archived it, Restore, and no ticking or step editing" do
    travel_to Time.utc(2026, 11, 14, 12)
    sign_in identities(:spouse)
    goal = goals(:proverbs)
    goal.archive(by: users(:head))
    goal.archival.update_column(:created_at, Time.utc(2026, 8, 30, 18))
    goal.steps.create!(title: "Read Proverbs 1", position: 1) # a finished goal takes no new steps through add_step

    get goal_path(goal)

    assert_select ".Banner", text: /Completed on October 30 by Sam Spouse\. Archived on August 30 by Hannah Head\./ do
      assert_select "form[action='#{archival_path(goal)}'] input[name=_method][value=delete]"
      assert_select "button", "Restore"
    end
    assert_select "action-menu form[action='#{archival_path(goal)}']", text: /Restore/
    assert_select "action-menu form[action='#{completion_path(goal)}']", count: 0
    assert_no_ticking_or_step_editing(goal)
  end

  private
    def completion_path(goal)
      household_goal_completion_path(household_id: goal.household, goal_id: goal)
    end

    def archival_path(goal)
      household_goal_archival_path(household_id: goal.household, goal_id: goal)
    end

    def assert_no_ticking_or_step_editing(goal)
      assert_select "#goal-steps .Box-row", count: 1
      assert_select "#goal-steps input[type=checkbox]", count: 0
      assert_select "#goal-steps form", count: 0
      assert_select "button[aria-label^='Edit step']", count: 0
      assert_select "form[action='#{household_goal_steps_path(household_id: goal.household, goal_id: goal)}']", count: 0
    end

    def valid_params
      { title: "Read Acts together", body: "To see how the early Christians preached.", target_on: "2027-06-30" }
    end

    def goal_path(goal)
      household_goal_path(household_id: goal.household, id: goal)
    end

    def edit_goal_path(goal)
      edit_household_goal_path(household_id: goal.household, id: goal)
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end

    def assert_text_on_page(text)
      assert_includes CGI.unescapeHTML(response.body), text
    end

    def queries_for(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
