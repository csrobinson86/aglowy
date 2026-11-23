require "test_helper"

# docs/design/notifications.md, Models (NotificationSetting) and Delivery (Starting the cursor).
class NotificationSettingTest < ActiveSupport::TestCase
  setup do
    @head = users(:head)
  end

  test "database: a second setting for one person's kind and channel raises RecordNotUnique" do
    @head.notification_settings.create!(kind: "weekly_preview", channel: "email")

    assert_raises ActiveRecord::RecordNotUnique do
      NotificationSetting.insert!({ user_id: @head.id, kind: "weekly_preview", channel: "email" })
    end
  end

  test "database: an unknown channel raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      NotificationSetting.insert!({ user_id: @head.id, kind: "weekly_preview", channel: "sms" })
    end
  end

  test "database: the go-bag use-by kind is one it takes" do
    assert_difference -> { NotificationSetting.count }, 1 do
      NotificationSetting.insert!({ user_id: @head.id, kind: "go_bag_use_by", channel: "email" })
    end
  end

  test "database: an unknown kind raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      NotificationSetting.insert!({ user_id: @head.id, kind: "streak_missed", channel: "email" })
    end
  end

  test "change replaces the person's settings, and nobody else's" do
    users(:spouse).notification_settings.change([ %w[ weekly_preview email ] ])
    @head.notification_settings.change([ %w[ weekly_preview email ], %w[ study_topic_needed email ] ])

    @head.notification_settings.change([ %w[ study_topic_needed email ], %w[ shared_with_you email ] ])

    assert_equal [ %w[ shared_with_you email ], %w[ study_topic_needed email ] ], @head.notification_settings.pluck(:kind, :channel).sort
    assert_equal [ %w[ weekly_preview email ] ], users(:spouse).notification_settings.pluck(:kind, :channel)

    @head.notification_settings.change([])

    assert_empty @head.notification_settings.reload
  end

  test "change keeps only what the person is offered: no unknown kind or channel, no kind for another role, no email for a child" do
    users(:spouse).notification_settings.change([ %w[ weekly_preview email ], %w[ weekly_preview sms ], %w[ streak_missed email ], %w[ study_topic_needed email ] ])
    users(:eli).notification_settings.change([ %w[ weekly_preview email ] ])

    assert_equal [ %w[ weekly_preview email ] ], users(:spouse).notification_settings.pluck(:kind, :channel)
    assert_empty users(:eli).notification_settings
  end

  test "change starts the summary cursor on the first summary-kind email, and leaves a set cursor alone" do
    freeze_time

    @head.notification_settings.change([ %w[ weekly_preview email ] ])
    assert_nil @head.reload.summary_sent_through, "a right-away kind starts no cursor"

    @head.notification_settings.change([ %w[ shared_with_you email ] ])
    assert_equal Time.current, @head.reload.summary_sent_through

    travel 2.days
    @head.notification_settings.change([ %w[ shared_with_you email ], %w[ invitation_unaccepted email ] ])
    assert_equal 2.days.ago, @head.reload.summary_sent_through
  end
end
