require "test_helper"

class MeetingNote::SharingTest < ActiveSupport::TestCase
  test "share and stop" do
    note = meeting_notes(:head_midweek)
    assert_empty note.shared_households

    note.share_with(households(:home))
    assert note.shared_with?(households(:home))
    assert_not note.shared_with?(households(:parents))
    assert_equal [ households(:home) ], note.shared_households

    # The same instance, not reloaded: the page answers from it after stopping.
    note.stop_sharing_with(households(:home))
    assert_not note.shared_with?(households(:home))
    assert_empty note.shared_households
  end

  test "sharing twice is one record" do
    note = meeting_notes(:head_midweek)

    2.times { note.share_with(households(:home)) }

    assert_equal 1, note.sharings.where(household: households(:home)).count
  end

  test "sharing is per household: stopping in one leaves the other" do
    note = meeting_notes(:head_midweek)
    note.share_with(households(:home))
    note.share_with(households(:parents))

    note.stop_sharing_with(households(:parents))

    assert_equal [ households(:home) ], note.reload.shared_households
  end

  test "share_with locks the household row" do
    assert_queries_match(/FROM "households" WHERE .* FOR UPDATE/) { meeting_notes(:head_midweek).share_with(households(:home)) }
  end

  # The recheck behind the lock: a deactivation that commits first leaves nothing to share into.
  test "share_with refuses a household where the author is no longer an active member" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    assert memberships(:spouse_in_home).deactivate

    assert_raises(ActiveRecord::RecordNotFound) { note.share_with(households(:home)) }
    assert_empty note.sharings
  end

  test "share_with refuses a household the author was never in" do
    assert_raises(ActiveRecord::RecordNotFound) { meeting_notes(:head_midweek).share_with(households(:other)) }
  end

  test "households_not_shared_with_besides names the author's other active households the note isn't shared with" do
    note = meeting_notes(:head_midweek)
    assert_equal [ households(:parents) ], note.households_not_shared_with_besides(households(:home)).to_a

    note.share_with(households(:parents))
    assert_empty note.households_not_shared_with_besides(households(:home))
  end

  test "deleting the note deletes its sharings" do
    note = meeting_notes(:head_midweek)
    note.share_with(households(:home))

    assert_difference -> { MeetingNote::Sharing.count }, -1 do
      note.destroy!
    end
  end

  test "database unique index on note and household" do
    meeting_notes(:head_midweek).share_with(households(:home))

    assert_raises ActiveRecord::RecordNotUnique do
      MeetingNote::Sharing.insert!({ meeting_note_id: meeting_notes(:head_midweek).id, household_id: households(:home).id })
    end
  end
end
