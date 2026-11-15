require "test_helper"

class Goal::StepTest < ActiveSupport::TestCase
  setup do
    @eli = users(:eli)
    @sofia = users(:sofia)
  end

  test "an everyone step is done after one tick with no person" do
    step = goal_steps(:read_john)
    assert step.everyone?
    assert_not step.done?

    step.tick(for: nil, by: users(:spouse))

    assert step.done?
    assert step.reload.done?
    assert step.done_for?(@eli), "a step done together is done for everyone"
  end

  test "the parables step isn't done with Eli's tick and is done after Sofia's" do
    step = goal_steps(:parables)
    assert_equal [ @eli, @sofia ].sort_by(&:id), step.assignees.sort_by(&:id)
    assert_not step.done?

    step.tick(for: @sofia, by: users(:spouse))

    assert step.done?
    assert step.reload.done?
  end

  test "done_for?(eli) is true on the parables step before Sofia ticks" do
    step = goal_steps(:parables)

    assert step.done_for?(@eli)
    assert_not step.done_for?(@sofia)
    assert_not step.done_for?(users(:spouse)), "a step that doesn't name someone is never done for them"
  end

  test "an assignee who isn't an active member of the household is invalid" do
    assignment = goal_steps(:read_john).assignments.new(user: users(:former))

    assert_not assignment.valid?
    assert_includes assignment.errors[:user], "must be an active member of the household"
    assert_not goal_steps(:read_john).assignments.new(user: users(:outsider)).valid?
    assert goal_steps(:read_john).assignments.new(user: @eli).valid?
  end

  test "a personal goal's steps can't have assignments" do
    step = goals(:spouse_bible_reading).add_step(title: "Read Genesis")

    assignment = step.assignments.new(user: users(:spouse))

    assert_not assignment.valid?
    assert_includes assignment.errors[:base], "A personal goal's steps are for its owner only"
  end

  test "a completion for someone not named on the step is invalid" do
    completion = goal_steps(:parables).completions.new(user: users(:spouse), completed_by: users(:spouse))

    assert_not completion.valid?
    assert_includes completion.errors[:user], "isn't named on this step"
  end

  test "a completion on a named step needs a person, and one on an everyone step mustn't have one" do
    together = goal_steps(:parables).completions.new(user: nil, completed_by: users(:spouse))
    assert_not together.valid?
    assert_includes together.errors[:user], "isn't named on this step"

    for_eli = goal_steps(:read_john).completions.new(user: @eli, completed_by: users(:spouse))
    assert_not for_eli.valid?
    assert_includes for_eli.errors[:user], "must be blank on a step for everyone"
  end

  test "ticking a step of a completed goal is refused" do
    step = goal_steps(:read_john)
    goals(:gospels).complete(by: users(:spouse))

    assert_raises(ActiveRecord::RecordInvalid) { step.tick(for: nil, by: users(:spouse)) }
    assert_empty step.completions.reload
  end

  test "ticking a step of an archived goal is refused, even from a step loaded before it was archived" do
    step = goal_steps(:read_john)
    assert step.goal.open?
    Goal::Archival.create!(goal: goals(:gospels), archived_by: users(:head))

    assert_raises(ActiveRecord::RecordInvalid) { step.tick(for: nil, by: users(:spouse)) }
  end

  test "ticking twice is a no-op" do
    step = goal_steps(:parables)

    step.tick(for: @eli, by: users(:spouse))

    assert_equal 1, step.completions.where(user: @eli).count
    assert_equal @eli, step.completions.find_by!(user: @eli).completed_by, "the first tick stays"
  end

  test "untick removes only that person's tick" do
    step = goal_steps(:parables)
    step.tick(for: @sofia, by: users(:spouse))

    step.untick(for: @eli)

    assert_not step.done?
    assert_not step.done_for?(@eli)
    assert step.done_for?(@sofia)
  end

  test "untick removes a done-together tick" do
    step = goal_steps(:read_matthew)

    step.untick(for: nil)

    assert_not step.done?
  end

  test "untick removes the tick of someone who has left" do
    step = goal_steps(:parables)
    assert memberships(:eli_in_home).deactivate

    step.untick(for: @eli)

    assert_not step.done_for?(@eli)
  end

  test "unticking a step of a completed goal is refused" do
    step = goal_steps(:read_matthew)
    goals(:gospels).complete(by: users(:spouse))

    assert_raises(ActiveRecord::RecordInvalid) { step.untick(for: nil) }
    assert step.reload.done?
  end

  test "reassigning the done Everyone step \"Read Matthew together\" to Eli deletes the done-together tick" do
    step = goal_steps(:read_matthew)
    assert step.done?

    step.reassign(to: [ @eli ])

    assert_equal [ @eli ], step.assignees
    assert_empty step.completions
    assert_not step.done?
    assert_not step.reload.done?
  end

  test "removing Eli from the parables step deletes his tick and keeps Sofia's assignment" do
    step = goal_steps(:parables)
    eli_tick = goal_step_completions(:parables_eli)

    step.reassign(to: [ @sofia ])

    assert_equal [ @sofia ], step.assignees
    assert goal_step_assignments(:parables_sofia).reload, "Sofia's assignment is the same record"
    assert_not Goal::Step::Completion.exists?(eli_tick.id)
  end

  test "adding someone to a named step leaves the others' ticks alone" do
    step = goal_steps(:parables)

    step.reassign(to: [ @eli, @sofia, users(:spouse) ])

    assert_equal 3, step.assignees.count
    assert step.done_for?(@eli)
  end

  test "reassigning a named step to everyone deletes the per-person ticks" do
    step = goal_steps(:parables)

    step.reassign(to: [])

    assert step.everyone?
    assert_empty step.completions
  end

  test "reassigning an everyone step to everyone keeps its done-together tick" do
    step = goal_steps(:read_matthew)

    step.reassign(to: [])

    assert step.done?
  end

  test "reassigning a step of a completed goal is refused and keeps its ticks" do
    step = goal_steps(:parables)
    goals(:gospels).complete(by: users(:spouse))

    assert_raises(ActiveRecord::RecordInvalid) { step.reassign(to: []) }
    assert_equal [ @eli, @sofia ].sort_by(&:id), step.assignees.sort_by(&:id)
    assert step.done_for?(@eli)
  end

  test "assignees loaded before a reassignment show the new people after it" do
    step = goal_steps(:parables)
    assert_includes step.assignees.load, @eli

    step.reassign(to: [ @sofia ])

    assert_equal [ @sofia ], step.assignees.to_a
  end

  test "reassigning to someone whose membership was just deactivated is refused" do
    step = goal_steps(:read_john)
    assert memberships(:sofia_in_home).deactivate

    assert_raises(ActiveRecord::RecordInvalid) { step.reassign(to: [ @eli, @sofia ]) }
    assert step.reload.everyone?, "nothing is written when one assignee is refused"
  end

  test "ticking for Eli after a reassignment has removed him is refused" do
    step = goal_steps(:parables)
    step.completions.where(user: @eli).delete_all
    assert_includes step.assignees.to_a, @eli

    Goal::Step.find(step.id).reassign(to: [ @sofia ])

    assert_raises(ActiveRecord::RecordInvalid) { step.tick(for: @eli, by: users(:spouse)) }
    assert_not step.completions.reload.exists?(user: @eli)
  end

  test "ticking for someone named on the step who has since left is refused" do
    step = goal_steps(:parables)
    assert memberships(:sofia_in_home).deactivate

    error = assert_raises(ActiveRecord::RecordInvalid) { step.tick(for: @sofia, by: users(:spouse)) }
    assert_includes error.record.errors[:user], "isn't an active member of the household"
  end

  test "add_step puts new steps last, with their assignees" do
    step = goals(:gospels).add_step(title: "Tell the congregation", due_on: Date.new(2027, 3, 31), assignees: [ @eli ])

    assert_equal 8, step.position
    assert_equal step, goals(:gospels).steps.last
    assert_equal [ @eli ], step.reload.assignees
    assert_equal 1, goals(:spouse_bible_reading).add_step(title: "Read Genesis").position
  end

  test "add_step refuses an assignee who isn't an active member, and a goal that isn't open" do
    assert_raises(ActiveRecord::RecordInvalid) { goals(:gospels).add_step(title: "Visit Grandma", assignees: [ users(:former) ]) }
    assert_raises(ActiveRecord::RecordInvalid) { goals(:proverbs).add_step(title: "Read chapter 1") }
    assert_equal 7, goals(:gospels).steps.count
    assert_empty goals(:proverbs).steps
  end

  test "a family goal's step writes lock the household row" do
    step = goal_steps(:read_john)

    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { goals(:gospels).add_step(title: "One more") }
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { step.reassign(to: [ @eli ]) }
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { step.tick(for: @eli, by: @eli) }
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { step.untick(for: @eli) }
  end

  test "a personal goal's step writes lock the goal row" do
    goal = goals(:spouse_bible_reading)

    step = assert_queries_match(/FROM "goals" WHERE .* FOR UPDATE/) { goal.add_step(title: "Read Genesis") }
    assert_queries_match(/FROM "goals" WHERE .* FOR UPDATE/) { step.tick(for: nil, by: users(:spouse)) }
    assert step.done?
    assert_queries_match(/FROM "goals" WHERE .* FOR UPDATE/) { step.untick(for: nil) }
    assert_not step.done?
  end

  test "done? and done_for? work from preloaded records without a query per step" do
    goal = Goal.preloaded.find(goals(:gospels).id)

    done = assert_queries_count(0) { goal.steps.map(&:done?) }
    assert_queries_count(0) { goal.steps.map { it.done_for?(@eli) } }

    assert_equal [ true, true, true, false, false, false, false ], done
  end

  test "title is required and encrypted at rest" do
    assert_not goals(:gospels).steps.new(position: 8).valid?

    raw = Goal::Step.connection.select_value(Goal::Step.where(id: goal_steps(:parables).id).select(:title).to_sql)
    assert_not_includes raw, "parables"
    assert_equal "Find three parables and explain one", goal_steps(:parables).title
  end

  test "database: two \"done together\" completions on one step raise RecordNotUnique (NULLS NOT DISTINCT)" do
    assert_raises ActiveRecord::RecordNotUnique do
      Goal::Step::Completion.insert!({ step_id: goal_steps(:read_matthew).id, completed_by_id: users(:head).id })
    end
  end

  test "database: two completions for the same person on one step raise RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Goal::Step::Completion.insert!({ step_id: goal_steps(:parables).id, user_id: @eli.id, completed_by_id: users(:head).id })
    end
  end

  test "database: the same person assigned twice raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Goal::Step::Assignment.insert!({ step_id: goal_steps(:parables).id, user_id: @eli.id })
    end
  end

  test "database: a step without a title raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goal_steps(:parables).update_column(:title, nil) }
  end

  test "database: a step without a position raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goal_steps(:parables).update_column(:position, nil) }
  end

  test "database: a completion without a completed_by raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goal_step_completions(:parables_eli).update_column(:completed_by_id, nil) }
  end

  test "database: an assignment without a user raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { goal_step_assignments(:parables_eli).update_column(:user_id, nil) }
  end

  test "database: deleting a linked family study leaves the step, unlinked" do
    step = goal_steps(:read_luke)
    step.update_column(:family_study_id, family_studies(:weekly).id)

    family_studies(:weekly).destroy!

    assert_nil step.reload.family_study_id
  end
end
