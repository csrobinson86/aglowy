require "test_helper"

class Goal::SharingTest < ActiveSupport::TestCase
  test "share and stop" do
    goal = goals(:spouse_bible_reading)
    assert_empty goal.shared_households

    goal.share_with(households(:home))
    assert goal.shared_with?(households(:home))
    assert_equal [ households(:home) ], goal.shared_households

    # The same instance, not reloaded: the page answers from it after stopping.
    goal.stop_sharing_with(households(:home))
    assert_not goal.shared_with?(households(:home))
    assert_empty goal.shared_households
  end

  test "sharing twice is one record" do
    2.times { goals(:spouse_bible_reading).share_with(households(:home)) }

    assert_equal 1, goals(:spouse_bible_reading).sharings.count
  end

  test "share_with locks the household row" do
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { goals(:spouse_bible_reading).share_with(households(:home)) }
  end

  # The recheck behind the lock: a deactivation that commits first leaves nothing to share into.
  test "share_with refuses a household where the owner is no longer an active member" do
    assert memberships(:spouse_in_home).deactivate

    assert_raises(ActiveRecord::RecordNotFound) { goals(:spouse_bible_reading).share_with(households(:home)) }
    assert_empty goals(:spouse_bible_reading).sharings
  end

  test "share_with refuses a household the owner was never in" do
    assert_raises(ActiveRecord::RecordNotFound) { goals(:spouse_bible_reading).share_with(households(:parents)) }
  end

  test "households_not_shared_with_besides names the owner's other active households the goal isn't shared with" do
    goal = users(:head).goals.create!(title: "Read the Psalms", target_on: Date.new(2027, 2, 28), set_by: users(:head))
    assert_equal [ households(:parents) ], goal.households_not_shared_with_besides(households(:home)).to_a

    goal.share_with(households(:parents))
    assert_empty goal.households_not_shared_with_besides(households(:home))
  end

  test "deleting the goal deletes its sharings" do
    goals(:spouse_bible_reading).share_with(households(:home))

    assert_difference -> { Goal::Sharing.count }, -1 do
      goals(:spouse_bible_reading).delete_for_good
    end
  end

  test "database: a second sharing of a goal with the same household raises RecordNotUnique" do
    goals(:spouse_bible_reading).share_with(households(:home))

    assert_raises ActiveRecord::RecordNotUnique do
      Goal::Sharing.insert!({ goal_id: goals(:spouse_bible_reading).id, household_id: households(:home).id })
    end
  end

  test "database: deleting a goal deletes its sharings" do
    goals(:spouse_bible_reading).share_with(households(:home))

    Goal.where(id: goals(:spouse_bible_reading).id).delete_all

    assert_not Goal::Sharing.exists?(household: households(:home))
  end
end
