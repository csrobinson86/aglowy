require "test_helper"

class Goal::Step::CompletionPolicyTest < ActiveSupport::TestCase
  test "head and adult tick an everyone step, their own part, and someone else's part" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      [ tick(:read_luke, nil), tick(:share_learned, :spouse), tick(:parables, :sofia) ].each do |completion|
        assert allowed?(membership, completion), "expected #{membership} to tick #{completion.step.title} for #{completion.user_id.inspect}"
      end
    end
  end

  test "a child ticks their own part, and nothing else" do
    assert allowed?(:eli_in_home, tick(:parables, :eli))
    assert allowed?(:eli_in_home, tick(:draw_map, :eli))
    assert allowed?(:eli_in_home, goal_step_completions(:parables_eli)), "expected Eli to untick his own part"

    assert_not allowed?(:eli_in_home, tick(:read_luke, nil)), "an everyone step"
    assert_not allowed?(:eli_in_home, goal_step_completions(:read_matthew_together)), "an everyone step's tick"
    assert_not allowed?(:eli_in_home, tick(:parables, :sofia)), "someone else's part"
    assert_not allowed?(:eli_in_home, tick(:read_luke, :eli)), "a step that doesn't name him"
    assert_not allowed?(:child_in_home, tick(:parables, :eli)), "another child's part"
  end

  test "nobody ticks on an archived goal" do
    goals(:gospels).archive(by: users(:spouse))

    assert_nobody_ticks
  end

  test "nobody ticks on a completed goal" do
    goals(:gospels).complete(by: users(:spouse))

    assert_nobody_ticks
  end

  test "a member of another household, an inactive member or a nil membership can't" do
    [ memberships(:outsider_in_other), memberships(:head_in_parents), memberships(:former_in_home), nil ].each do |membership|
      policy = Goal::Step::CompletionPolicy.new(membership, tick(:read_luke, nil))

      assert_not policy.create? || policy.destroy?, "expected #{membership.inspect} to be refused"
    end
  end

  test "personal goal: the owner ticks done together, from any household, whatever their role" do
    spouse_step = goals(:spouse_bible_reading).add_step(title: "Read Genesis")
    head_step = users(:head).goals.create!(title: "Read the Psalms", target_on: Date.new(2027, 2, 28), set_by: users(:head)).add_step(title: "Psalm 1")
    eli_step = users(:eli).goals.create!(title: "Read my story book", target_on: Date.new(2027, 2, 28), set_by: users(:eli)).add_step(title: "Story 1")

    assert allowed?(:spouse_in_home, spouse_step.new_tick(nil))
    assert allowed?(:head_in_home, head_step.new_tick(nil))
    assert allowed?(:head_in_parents, head_step.new_tick(nil))
    assert allowed?(:eli_in_home, eli_step.new_tick(nil)), "a child runs their own goals"
    assert allowed?(:spouse_in_home, spouse_step.tick(for: nil, by: users(:spouse))), "the owner unticks"
  end

  test "personal goal: never a part for a person" do
    step = goals(:spouse_bible_reading).add_step(title: "Read Genesis")

    assert_not allowed?(:spouse_in_home, step.new_tick(users(:spouse).id))
  end

  test "personal goal: nobody else, whatever their role, an inactive owner, or a nil membership" do
    step = goals(:spouse_bible_reading).add_step(title: "Read Genesis")

    %i[ head_in_home child_in_home eli_in_home outsider_in_other ].each do |membership|
      assert_not allowed?(membership, step.new_tick(nil)), "expected #{membership} to be refused"
    end
    assert_not Goal::Step::CompletionPolicy.new(nil, step.new_tick(nil)).create?

    memberships(:spouse_in_home).update_column(:active, false)
    assert_not allowed?(:spouse_in_home, step.new_tick(nil))
  end

  test "personal goal: nobody ticks once it's completed or archived" do
    goal = goals(:spouse_bible_reading)
    step = goal.add_step(title: "Read Genesis")

    goal.complete(by: users(:spouse))
    assert_not allowed?(:spouse_in_home, step.new_tick(nil))

    goal.reopen
    goal.archive(by: users(:spouse))
    assert_not allowed?(:spouse_in_home, step.new_tick(nil))
  end

  private
    def tick(step, user)
      goal_steps(step).new_tick(user && users(user).id)
    end

    def assert_nobody_ticks
      %i[ head_in_home spouse_in_home eli_in_home ].each do |membership|
        [ tick(:read_luke, nil), tick(:parables, :eli), tick(:parables, :sofia), goal_step_completions(:parables_eli) ].each do |completion|
          assert_not allowed?(membership, completion), "expected #{membership} to be refused on a closed goal"
        end
      end
    end

    def allowed?(membership, completion)
      policy = Goal::Step::CompletionPolicy.new(memberships(membership), completion)
      assert_equal policy.create?, policy.destroy?
      policy.create?
    end
end
