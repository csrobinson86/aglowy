require "test_helper"

# docs/design/notifications.md, Models (Notification, Notification::Reading) and The kinds (shared_with_you).
class NotificationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @note = meeting_notes(:head_midweek)
  end

  test "database: a second notification with one person's dedupe key raises RecordNotUnique" do
    shared_with_spouse

    assert_raises ActiveRecord::RecordNotUnique do
      Notification.insert!({ user_id: users(:spouse).id, household_id: households(:home).id, kind: "shared_with_you",
                             subject_type: "MeetingNote", subject_id: @note.id, dedupe_key: "shared_with_you:1" })
    end
  end

  test "database: an unknown kind raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Notification.insert!({ user_id: users(:spouse).id, household_id: households(:home).id, kind: "streak_missed",
                             subject_type: "MeetingNote", subject_id: @note.id, dedupe_key: "streak_missed:1" })
    end
  end

  test "visible leaves out a household the person left" do
    from_home = shared_with_spouse
    from_parents = users(:head).notify(kind: "shared_with_you", household: households(:parents), subject: @note, actor: users(:grandparent), dedupe_key: "shared_with_you:2")

    assert_equal [ from_home, from_parents ].sort_by(&:id), Notification.visible.where(id: [ from_home, from_parents ]).sort_by(&:id)

    memberships(:head_in_parents).deactivate

    assert_equal [ from_home ], Notification.visible.where(id: [ from_home, from_parents ]).to_a
    assert Notification.exists?(from_parents.id), "leaving hides a household's notifications, it doesn't delete them (Trap 8)"
  end

  test "unread leaves out read ones" do
    read = shared_with_spouse
    unread = users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: goals(:spouse_bible_reading), actor: users(:head), dedupe_key: "shared_with_you:2")

    read.read
    read.read

    assert_equal [ unread ], users(:spouse).notifications.unread.to_a
    assert_equal 1, Notification::Reading.where(notification: read).count
  end

  test "deleting the shared note deletes its notifications" do
    notification = shared_with_spouse

    @note.destroy!

    assert_not Notification.exists?(notification.id)
  end

  test "a renamed household and a renamed sharer show their new names" do
    notification = shared_with_spouse
    households(:home).update!(name: "The Renamed Family")
    users(:head).update!(name: "Henrietta Head")

    notification = Notification.find(notification.id)

    assert_equal "The Renamed Family", notification.household.name
    assert_equal "Henrietta shared a meeting note", notification.title
  end

  test "a shared meeting note's wording, icon and target" do
    notification = shared_with_spouse

    assert_equal "Hannah shared a meeting note", notification.title
    assert_equal "Life and Ministry · week of November 16", notification.body
    assert_equal :share, notification.icon
    assert_equal :summary, notification.email
    assert_equal "/#{households(:home).id}/meeting_notes/#{@note.id}", notification.target_path
  end

  test "a shared weekend note names the weekend meeting" do
    notification = users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: meeting_notes(:head_weekend), actor: users(:head), dedupe_key: "shared_with_you:1")

    assert_equal "Weekend meeting · week of November 16", notification.body
  end

  test "a shared goal's wording and target, under the notification's own household" do
    notification = users(:head).notify(kind: "shared_with_you", household: households(:parents), subject: goals(:spouse_bible_reading), actor: users(:spouse), dedupe_key: "shared_with_you:1")

    assert_equal "Sam shared a goal", notification.title
    assert_equal "Read the whole Bible in a year", notification.body
    assert_equal "/#{households(:parents).id}/goals/#{goals(:spouse_bible_reading).id}", notification.target_path
  end

  test "a sharer who was deleted is someone" do
    notification = shared_with_spouse
    notification.update_column(:actor_id, nil)

    assert_equal "Someone shared a meeting note", Notification.find(notification.id).title
  end

  test "deliver_later enqueues the delivery job, which sends nothing yet" do
    notification = shared_with_spouse

    assert_enqueued_with(job: Notification::DeliveryJob, args: [ notification ]) { notification.deliver_later }
    assert_nothing_raised { perform_enqueued_jobs }
  end

  test "reading broadcasts the person's new count to their own stream" do
    notification = shared_with_spouse

    assert_turbo_stream_broadcasts [ users(:spouse), :notifications ], count: 2 do
      notification.read
    end
  end

  private
    def shared_with_spouse
      users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: @note, actor: users(:head), dedupe_key: "shared_with_you:1")
    end
end
