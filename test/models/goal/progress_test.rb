require "test_helper"

# The Rivera goal from frame milestone-goal.png: Maria is `spouse`, Daniel is `head`. The `home`
# household also has Charlie, a child the frame doesn't show, and Frances, who has left.
class Goal::ProgressTest < ActiveSupport::TestCase
  test "3 of 7 done, next step \"Read Luke together\" due Feb 15" do
    progress = goals(:gospels).progress

    assert_equal 3, progress.done_count
    assert_equal 7, progress.steps_count
    assert_equal 4, progress.remaining_count
    assert_equal 42, progress.percent
    assert_not progress.all_done?
    assert_equal goal_steps(:read_luke), progress.next_step
    assert_equal Date.new(2027, 2, 15), progress.next_step.due_on
  end

  test "next due is the earliest due date among the steps still to do" do
    goal = goals(:gospels)
    assert_equal Date.new(2027, 2, 15), goal.progress.next_due_on

    goal.add_step(title: "Pray about it", due_on: Date.new(2027, 1, 5))
    goal_steps(:read_luke).tick(for: nil, by: users(:spouse))
    assert_equal Date.new(2027, 1, 5), goal.reload.progress.next_due_on

    goal.steps.where.not(due_on: nil).update_all(due_on: nil)
    assert_nil goal.reload.progress.next_due_on
  end

  test "Maria 2 of 5, Daniel 2 of 4, Eli 4 of 6, Sofia 2 of 5" do
    people = goals(:gospels).progress.people.index_by(&:user)

    assert_equal [ 2, 5 ], people[users(:spouse)].then { [ it.done_count, it.steps_count ] }
    assert_equal [ 2, 4 ], people[users(:head)].then { [ it.done_count, it.steps_count ] }
    assert_equal [ 4, 6 ], people[users(:eli)].then { [ it.done_count, it.steps_count ] }
    assert_equal [ 2, 5 ], people[users(:sofia)].then { [ it.done_count, it.steps_count ] }
    assert_equal [ 2, 4 ], people[users(:child)].then { [ it.done_count, it.steps_count ] }
  end

  test "people are the household's active members, in membership order, with their names" do
    people = goals(:gospels).progress.people

    assert_equal [ users(:head), users(:spouse) ], people.first(2).map(&:user), "heads, then adults, then children"
    assert_equal [ users(:child), users(:eli), users(:sofia) ].sort_by(&:id), people.drop(2).map(&:user).sort_by(&:id)
    assert_not_includes people.map(&:user), users(:former), "someone who has left isn't counted"
    assert_equal "Hannah Head", people.first.name
  end

  test "a goal with no steps: 0 of 0, not all done" do
    progress = goals(:songs).progress

    assert_equal 0, progress.done_count
    assert_equal 0, progress.steps_count
    assert_equal 0, progress.remaining_count
    assert_equal 0, progress.percent
    assert_not progress.all_done?
    assert_nil progress.next_step
  end

  test "every step done: all done, 100%, no next step" do
    goal_steps(:parables).tick(for: users(:sofia), by: users(:spouse))
    %i[ read_luke read_john ].each { goal_steps(it).tick(for: nil, by: users(:spouse)) }
    goal_steps(:share_learned).tick(for: users(:spouse), by: users(:spouse))

    progress = goals(:gospels).progress

    assert progress.all_done?
    assert_equal 100, progress.percent
    assert_nil progress.next_step
  end

  test "a personal goal has no people" do
    goals(:spouse_bible_reading).add_step(title: "Read Genesis")

    assert_empty goals(:spouse_bible_reading).progress.people
    assert_equal 1, goals(:spouse_bible_reading).progress.steps_count
  end

  test "built from Goal.preloaded, it runs no further queries" do
    goal = Goal.preloaded.find(goals(:gospels).id)

    assert_queries_count(0) do
      progress = goal.progress
      progress.done_count
      progress.next_step&.due_on
      progress.next_due_on
      progress.people.each { [ it.name, it.done_count, it.steps_count ] }
    end
  end
end
