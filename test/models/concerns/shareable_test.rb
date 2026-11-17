require "test_helper"

# Sharing tells the household (docs/design/notifications.md, The kinds: shared_with_you).
class ShareableTest < ActiveSupport::TestCase
  test "sharing notifies every other active member, not the sharer and not an inactive member" do
    note = meeting_notes(:head_midweek)

    note.share_with(households(:home))

    sharing = note.sharings.sole
    notifications = Notification.where(subject: note)
    assert_equal users(:spouse, :child, :eli, :sofia).map(&:id).sort, notifications.map(&:user_id).sort
    assert notifications.all? { it.kind == "shared_with_you" && it.household == households(:home) && it.actor == users(:head) }
    assert notifications.all? { it.dedupe_key == "shared_with_you:#{sharing.id}" }
    assert_not Notification.exists?(user: users(:former))
    assert_not Notification.exists?(user: users(:head))
  end

  test "sharing twice notifies once" do
    note = meeting_notes(:head_midweek)

    note.share_with(households(:home))

    assert_no_difference -> { Notification.count } do
      note.share_with(households(:home))
    end
  end

  test "sharing a personal goal notifies the household too" do
    goal = goals(:spouse_bible_reading)

    goal.share_with(households(:home))

    assert_equal "Sam shared a goal", users(:head).notifications.sole.title
  end

  test "stopping sharing deletes the household's notifications of it, not another household's" do
    note = meeting_notes(:head_midweek)
    note.share_with(households(:home))
    note.share_with(households(:parents))

    note.stop_sharing_with(households(:home))

    assert_not Notification.exists?(subject: note, household: households(:home))
    assert_equal [ users(:grandparent) ], Notification.where(subject: note).map(&:user)
  end

  test "leaving the household deletes the notifications of the person's notes and goals shared there" do
    note, goal = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16)), goals(:spouse_bible_reading)
    note.share_with(households(:home))
    goal.share_with(households(:home))
    meeting_notes(:head_midweek).share_with(households(:home))

    memberships(:spouse_in_home).deactivate

    assert_not Notification.exists?(subject: [ note, goal ])
    assert Notification.exists?(subject: meeting_notes(:head_midweek), user: users(:child))
  end
end
