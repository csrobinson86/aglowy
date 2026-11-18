require "test_helper"

# What shared_with_you says and opens for each subject (docs/design/notifications.md, The kinds; docs/design/meeting-parts.md,
# Sharing). Meeting notes and goals are covered in test/models/notification_test.rb.
class Notification::Kind::SharedWithYouTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "a shared meeting part: who shared it, the kind and date, opening the part under the notification's household" do
    part = meeting_parts(:spouse_talk)
    part.update!(meeting_on: Date.new(2026, 12, 10))

    notification = users(:head).notify(kind: "shared_with_you", household: households(:home), subject: part, actor: users(:spouse), dedupe_key: "shared_with_you:1")

    assert_equal "Sam shared a meeting part", notification.title
    assert_equal "Talk · Thursday, December 10", notification.body
    assert_equal household_meeting_part_path(household_id: households(:home), id: part), notification.target_path
  end

  test "a shared meeting part never shows its topic, preparation or counsel" do
    part = meeting_parts(:spouse_talk)
    part.update!(preparation: "<p>Open with a question</p>", counsel: "Slow down at the start.")

    notification = users(:head).notify(kind: "shared_with_you", household: households(:home), subject: part, actor: users(:spouse), dedupe_key: "shared_with_you:1")

    [ notification.title, notification.body ].each do |text|
      assert_no_match(/trust the Bible|Open with a question|Slow down/, text)
    end
  end
end
