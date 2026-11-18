require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "role defaults to adult" do
    assert Membership.new.adult?
  end

  test "by_household_name orders by the household's name" do
    assert_equal [ households(:parents), households(:home) ], users(:head).memberships.by_household_name.map(&:household)
  end

  test "an unknown role is a validation error, not an ArgumentError" do
    membership = Membership.new(household: households(:home), user: users(:newcomer), role: "admin")

    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "database: role admin raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Membership.insert!({ household_id: households(:home).id, user_id: users(:newcomer).id, role: "admin" })
    end
  end

  test "database: the same person twice in one household raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Membership.insert!({ household_id: households(:home).id, user_id: users(:head).id })
    end
  end

  test "database: a membership for a missing household raises InvalidForeignKey" do
    assert_raises ActiveRecord::InvalidForeignKey do
      Membership.insert!({ household_id: SecureRandom.uuid_v7, user_id: users(:newcomer).id })
    end
  end

  test "sole_head? is true for the only active head" do
    assert memberships(:head_in_home).sole_head?
  end

  test "sole_head? is false with another active head" do
    memberships(:spouse_in_home).update!(role: :head)

    assert_not memberships(:head_in_home).sole_head?
  end

  test "sole_head? is false for adults" do
    assert_not memberships(:spouse_in_home).sole_head?
  end

  test "an inactive head doesn't count" do
    memberships(:former_in_home).update!(role: :head)

    assert memberships(:head_in_home).sole_head?
  end

  test "deactivate refuses the sole head" do
    membership = memberships(:head_in_home)

    assert_not membership.deactivate
    assert membership.reload.active?
    assert_includes membership.errors[:base], "A household needs at least one active head"
  end

  test "deactivate works for an adult" do
    assert memberships(:spouse_in_home).deactivate
    assert_not memberships(:spouse_in_home).reload.active?
  end

  test "deactivate deletes the person's meeting-note sharings into that household only" do
    note = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    note.share_with(households(:home))
    note.share_with(households(:parents))
    meeting_notes(:head_midweek).share_with(households(:home))
    users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16)).share_with(households(:home))
    memberships(:spouse_in_home).update!(role: :head)

    assert_difference -> { MeetingNote::Sharing.count }, -2 do
      assert memberships(:head_in_home).deactivate
    end
    assert_equal [ households(:parents) ], note.reload.shared_households
  end

  test "deactivate deletes the person's goal sharings into that household only" do
    goal = users(:head).goals.create!(title: "Read the Psalms", target_on: Date.new(2027, 2, 28), set_by: users(:head))
    goal.share_with(households(:home))
    goal.share_with(households(:parents))
    goals(:spouse_bible_reading).share_with(households(:home))
    memberships(:spouse_in_home).update!(role: :head)

    assert_difference -> { Goal::Sharing.count }, -1 do
      assert memberships(:head_in_home).deactivate
    end
    assert_equal [ households(:parents) ], goal.reload.shared_households
  end

  test "deactivate deletes the person's meeting-part sharings there and withdraws their notifications; rejoining doesn't bring them back" do
    part = meeting_parts(:head_conversation)
    part.share_with(households(:home))
    part.share_with(households(:parents))
    meeting_parts(:spouse_talk).share_with(households(:home))
    memberships(:spouse_in_home).update!(role: :head)

    assert_difference -> { MeetingPart::Sharing.count }, -1 do
      assert memberships(:head_in_home).deactivate
    end
    assert_equal [ households(:parents) ], part.reload.shared_households
    assert_equal [ households(:parents).id ], Notification.where(subject: part).distinct.pluck(:household_id)
    assert Notification.exists?(subject: meeting_parts(:spouse_talk))

    memberships(:head_in_home).update!(active: true)

    assert_not_includes MeetingPart.shared_with(households(:home)), part
  end

  test "a refused deactivate keeps the person's sharings" do
    meeting_notes(:head_midweek).share_with(households(:home))

    assert_no_difference -> { MeetingNote::Sharing.count } do
      assert_not memberships(:head_in_home).deactivate
    end
  end

  test "deactivating Sofia removes her from the open parables step, which becomes done because Eli ticked; her assignment on a done step stays" do
    sofia = users(:sofia)
    map = goal_steps(:draw_map)
    map.reassign(to: [ users(:eli), sofia ])
    map.tick(for: sofia, by: users(:spouse))

    assert memberships(:sofia_in_home).deactivate

    parables = goal_steps(:parables).reload
    assert_equal [ users(:eli) ], parables.assignees.to_a
    assert parables.done?
    assert_includes map.reload.assignees, sofia
    assert map.completions.exists?(user: sofia)
  end

  test "deactivating Eli instead removes his assignment and his tick from the open parables step, leaving it for Sofia alone" do
    eli = users(:eli)

    assert memberships(:eli_in_home).deactivate

    parables = goal_steps(:parables).reload
    assert_equal [ users(:sofia) ], parables.assignees.to_a
    assert_not parables.completions.exists?(user: eli)
    assert_not parables.done?
    map = goal_steps(:draw_map).reload
    assert_equal [ eli ], map.assignees.to_a, "a done step keeps its assignments and ticks as history"
    assert map.done?
  end

  test "deactivate leaves the person's open steps in their other households" do
    head = users(:head)
    goal = households(:parents).goals.create!(set_by: head, title: "Visit the sick", target_on: Date.new(2027, 5, 1))
    parents_step = goal.add_step(title: "Bake bread", assignees: [ head ])
    home_step = goal_steps(:read_john)
    home_step.reassign(to: [ head ])

    assert memberships(:head_in_parents).deactivate

    assert_empty parents_step.reload.assignees
    assert_equal [ head ], home_step.reload.assignees.to_a
  end

  test "change_role refuses to demote the sole head" do
    membership = memberships(:head_in_home)

    assert_not membership.change_role(:adult)
    assert membership.reload.head?
    assert_includes membership.errors[:base], "A household needs at least one active head"
  end

  test "change_role demotes a head when another active head exists" do
    memberships(:spouse_in_home).update!(role: :head)

    assert memberships(:head_in_home).change_role(:adult)
    assert memberships(:head_in_home).reload.adult?
  end

  test "deactivate reads the seat again under the lock, so a copy loaded before a promotion can't remove the last head" do
    loaded_as_adult = Membership.find(memberships(:spouse_in_home).id)
    memberships(:spouse_in_home).update!(role: :head)
    assert memberships(:head_in_home).deactivate

    assert_not loaded_as_adult.deactivate
    assert memberships(:spouse_in_home).reload.active?
  end

  test "deactivate locks the household row" do
    assert_queries_match(/FOR UPDATE/) { memberships(:spouse_in_home).deactivate }
  end

  test "change_role locks the household row" do
    assert_queries_match(/FOR UPDATE/) { memberships(:spouse_in_home).change_role(:child) }
  end

  test "share_times twice makes one row" do
    membership = memberships(:spouse_in_home)

    assert_difference -> { Membership::TimeSharing.count }, 1 do
      membership.share_times
      membership.share_times
    end
    assert membership.shares_times?
  end

  test "stop_sharing_times removes it" do
    membership = memberships(:spouse_in_home)
    membership.share_times

    membership.stop_sharing_times

    assert_not membership.shares_times?
    assert_not Membership::TimeSharing.exists?(membership:)
  end

  test "database: a second time sharing for one membership raises RecordNotUnique" do
    memberships(:spouse_in_home).share_times

    assert_raises(ActiveRecord::RecordNotUnique) { Membership::TimeSharing.insert!({ membership_id: memberships(:spouse_in_home).id }) }
  end

  test "database: deleting the seat deletes its time sharing" do
    memberships(:spouse_in_home).share_times

    Membership.where(id: memberships(:spouse_in_home).id).delete_all

    assert_not Membership::TimeSharing.exists?
  end
end
