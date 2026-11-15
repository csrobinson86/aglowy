require "test_helper"

class GoalTest < ActiveSupport::TestCase
  test "reachable_from: the household's goals and the person's own personal goals, nothing else" do
    assert_equal [ goals(:gospels), goals(:proverbs), goals(:songs), goals(:spouse_bible_reading) ].sort_by(&:id),
                 Goal.reachable_from(memberships(:spouse_in_home)).sort_by(&:id)
    assert_equal [ goals(:gospels), goals(:proverbs), goals(:songs) ].sort_by(&:id), Goal.reachable_from(memberships(:head_in_home)).sort_by(&:id)
    assert_equal [ goals(:outsiders_reading) ], Goal.reachable_from(memberships(:outsider_in_other)).to_a
  end

  test "reachable_from also reaches personal goals shared into the household; family_or_own doesn't" do
    goals(:spouse_bible_reading).share_with(households(:home))

    assert_includes Goal.reachable_from(memberships(:head_in_home)), goals(:spouse_bible_reading)
    assert_not_includes Goal.family_or_own(memberships(:head_in_home)), goals(:spouse_bible_reading)
    assert_not_includes Goal.reachable_from(memberships(:head_in_parents)), goals(:spouse_bible_reading)
  end

  test "shared_with includes a shared goal" do
    goals(:spouse_bible_reading).share_with(households(:home))

    assert_equal [ goals(:spouse_bible_reading) ], Goal.shared_with(households(:home)).to_a
  end

  test "shared_with excludes a goal after its owner stops sharing" do
    goals(:spouse_bible_reading).share_with(households(:home))
    goals(:spouse_bible_reading).stop_sharing_with(households(:home))

    assert_empty Goal.shared_with(households(:home))
  end

  test "shared_with excludes a goal once its owner leaves the household" do
    goals(:spouse_bible_reading).share_with(households(:home))

    assert memberships(:spouse_in_home).deactivate

    assert_empty Goal.shared_with(households(:home))
  end

  # The second guard: a sharing row left behind while the owner is inactive still never shows.
  test "shared_with excludes a goal whose owner is inactive even if its sharing is still there" do
    goals(:spouse_bible_reading).share_with(households(:home))

    memberships(:spouse_in_home).update_column(:active, false)

    assert_equal 1, goals(:spouse_bible_reading).sharings.count
    assert_empty Goal.shared_with(households(:home))
  end

  test "shared_with stays excluded after the owner leaves and rejoins" do
    goals(:spouse_bible_reading).share_with(households(:home))
    assert memberships(:spouse_in_home).deactivate

    memberships(:spouse_in_home).update!(active: true)

    assert_empty Goal.shared_with(households(:home))
  end

  test "a family goal can't be shared" do
    assert_raises(ActiveRecord::RecordNotFound) { goals(:gospels).share_with(households(:home)) }

    sharing = Goal::Sharing.new(goal: goals(:gospels), household: households(:home))
    assert_not sharing.valid?
    assert_includes sharing.errors[:goal], "must be a personal goal"
    assert_empty Goal.shared_with(households(:home))
  end

  test "active, completed and archived hold the right fixtures, in the right order" do
    assert_equal [ goals(:spouse_bible_reading), goals(:gospels), goals(:outsiders_reading) ], Goal.active
    assert_equal [ goals(:gospels) ], households(:home).goals.active
    assert_equal [ goals(:proverbs) ], Goal.completed
    assert_equal [ goals(:songs) ], Goal.archived

    goals(:gospels).complete(by: users(:head))
    assert_equal [ goals(:gospels), goals(:proverbs) ], Goal.completed, "expected the newest completion first"

    # A completed goal that's archived shows in Archived only.
    goals(:proverbs).archive(by: users(:head))
    assert_equal [ goals(:proverbs), goals(:songs) ], Goal.archived, "expected the newest archival first"
    assert_equal [ goals(:gospels) ], Goal.completed
  end

  test "complete then reopen returns a goal to active" do
    goal = goals(:gospels)

    goal.complete(by: users(:spouse))
    assert goal.completed?
    assert_not goal.open?
    assert_equal users(:spouse), goal.completion.completed_by
    assert_includes Goal.completed, goal

    goal.reopen
    assert goal.open?
    assert_not goal.completed?
    assert_includes Goal.active, goal
  end

  test "archive a completed goal, then restore puts it back in completed" do
    goal = goals(:proverbs)

    goal.archive(by: users(:spouse))
    assert goal.archived?
    assert_equal users(:spouse), goal.archival.archived_by
    assert_equal [ goal, goals(:songs) ], Goal.archived
    assert_not_includes Goal.completed, goal

    goal.restore
    assert_not goal.archived?
    assert goal.completed?
    assert_includes Goal.completed, goal
  end

  test "an active goal that's archived and restored is active again" do
    goal = goals(:gospels)

    goal.archive(by: users(:head))
    assert_not goal.open?

    goal.restore
    assert goal.open?
    assert_includes Goal.active, goal
  end

  test "completing or archiving twice is a no-op, not an error" do
    goal = goals(:gospels)

    2.times { goal.complete(by: users(:head)) }
    2.times { goal.archive(by: users(:head)) }

    assert_equal 1, Goal::Completion.where(goal: goal).count
    assert_equal 1, Goal::Archival.where(goal: goal).count
  end

  test "reopening an open goal and restoring an unarchived one are no-ops" do
    goal = goals(:gospels)

    goal.reopen
    goal.restore

    assert goal.open?
  end

  test "an archived goal isn't completed or reopened until it's restored" do
    goals(:songs).complete(by: users(:head))
    assert_not goals(:songs).reload.completed?

    proverbs = goals(:proverbs)
    proverbs.archive(by: users(:head))
    proverbs.reopen
    assert proverbs.reload.completed?
  end

  test "lifecycle writes recheck the goal's state in the database, not the loaded record" do
    goal = goals(:gospels)
    assert goal.open?
    Goal::Completion.create!(goal: goal, completed_by: users(:spouse))

    goal.complete(by: users(:head))

    assert_equal users(:spouse), Goal::Completion.find_by!(goal: goal).completed_by
  end

  test "a family goal's lifecycle writes lock the household row" do
    goal = goals(:gospels)

    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { goal.complete(by: users(:head)) }
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { goal.reopen }
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { goal.archive(by: users(:head)) }
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { goal.restore }
  end

  test "a personal goal's lifecycle writes lock the goal row" do
    goal = goals(:spouse_bible_reading)

    assert_queries_match(/FROM "goals" WHERE .* FOR UPDATE/) { goal.complete(by: users(:spouse)) }
    assert_queries_match(/FROM "goals" WHERE .* FOR UPDATE/) { goal.reopen }
    assert_queries_match(/FROM "goals" WHERE .* FOR UPDATE/) { goal.archive(by: users(:spouse)) }
    assert_queries_match(/FROM "goals" WHERE .* FOR UPDATE/) { goal.restore }
  end

  test "family? and personal?" do
    assert goals(:gospels).family?
    assert_not goals(:gospels).personal?
    assert goals(:spouse_bible_reading).personal?
    assert_not goals(:spouse_bible_reading).family?
  end

  test "a person's goals are their personal goals, never the family goals they set" do
    assert_equal users(:spouse), goals(:gospels).set_by
    assert_equal [ goals(:spouse_bible_reading) ], users(:spouse).goals
    assert_empty users(:head).goals
  end

  test "a household's goals are its family goals" do
    assert_equal [ goals(:gospels), goals(:proverbs), goals(:songs) ].sort_by(&:id), households(:home).goals.sort_by(&:id)
  end

  test "title and target_on are required" do
    goal = households(:home).goals.new(set_by: users(:head))

    assert_not goal.valid?
    assert_includes goal.errors[:title], "can't be blank"
    assert_includes goal.errors[:target_on], "can't be blank"
  end

  test "a new goal is a milestone" do
    assert households(:home).goals.new.milestone?
  end

  test "title is encrypted at rest (the raw column isn't the plain title)" do
    goal = goals(:gospels)
    raw = Goal.connection.select_one(Goal.where(id: goal.id).select(:title, :body).to_sql)

    assert_not_includes raw["title"], "Gospels"
    assert_not_includes raw["body"], "Jesus"
    assert_equal "Read the four Gospels together", goal.title
  end

  test "database: both household_id and user_id set raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      goals(:gospels).update_column(:user_id, users(:head).id)
    end
  end

  test "database: neither household_id nor user_id set raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      goals(:gospels).update_column(:household_id, nil)
    end
  end

  test "database: kind habit raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Goal.where(id: goals(:gospels).id).update_all(kind: "habit")
    end
  end

  test "database: a goal without a title raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goals(:gospels).update_column(:title, nil) }
  end

  test "database: a goal without a target_on raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goals(:gospels).update_column(:target_on, nil) }
  end

  test "database: a goal without a set_by raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goals(:gospels).update_column(:set_by_id, nil) }
  end

  test "database: a set_by that isn't a user raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { goals(:gospels).update_column(:set_by_id, SecureRandom.uuid_v7) }
  end

  test "database: a second completion for the same goal raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Goal::Completion.insert!({ goal_id: goals(:proverbs).id, completed_by_id: users(:head).id })
    end
  end

  test "database: a second archival for the same goal raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Goal::Archival.insert!({ goal_id: goals(:songs).id, archived_by_id: users(:spouse).id })
    end
  end

  test "database: a completion without a completed_by raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goal_completions(:proverbs).update_column(:completed_by_id, nil) }
  end

  test "database: an archival without an archived_by raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goal_archivals(:songs).update_column(:archived_by_id, nil) }
  end

  test "a goal's steps are in position order" do
    goal_steps(:read_matthew).update_column(:position, 9)

    assert_equal "Read Mark together", goals(:gospels).steps.first.title
    assert_equal "Read Matthew together", goals(:gospels).steps.last.title
  end

  test "preloaded includes steps with their assignments and completions" do
    goal = Goal.preloaded.find(goals(:gospels).id)

    assert goal.association(:steps).loaded?
    assert goal.steps.all? { it.association(:assignments).loaded? && it.association(:completions).loaded? }
  end

  test "delete_for_good wins over an edit saved since the goal was loaded" do
    goal = Goal.find(goals(:gospels).id)
    Goal.find(goal.id).update!(title: "Read the Gospels")

    goal.delete_for_good

    assert_not Goal.exists?(goal.id)
  end

  test "deleting a family goal takes the household lock first, like its other writes" do
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { goals(:gospels).delete_for_good }
  end

  test "a family goal's writes are RecordNotFound once someone else has deleted it" do
    goal = Goal.find(goals(:gospels).id)
    Goal.find(goal.id).delete_for_good

    assert_raises(ActiveRecord::RecordNotFound) { goal.add_step(title: "Read Acts") }
    assert_raises(ActiveRecord::RecordNotFound) { goal.complete(by: users(:head)) }
  end

  test "database: deleting a goal deletes its steps, assignments and completions" do
    goal = goals(:gospels)
    step_ids = goal.steps.ids

    Goal.where(id: goal.id).delete_all

    assert_not Goal::Step.exists?(goal_id: goal.id)
    assert_not Goal::Step::Assignment.exists?(step_id: step_ids)
    assert_not Goal::Step::Completion.exists?(step_id: step_ids)
  end

  test "database: deleting a goal deletes its completion and archival" do
    goal = goals(:proverbs)
    goal.archive(by: users(:head))

    Goal.where(id: goal.id).delete_all

    assert_not Goal::Completion.exists?(goal_id: goal.id)
    assert_not Goal::Archival.exists?(goal_id: goal.id)
  end
end
