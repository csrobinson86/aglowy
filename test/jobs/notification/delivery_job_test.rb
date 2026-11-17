require "test_helper"

# The email part of delivery (docs/design/notifications.md, Delivery, step 2; Notification::Delivery; Traps 2 and 3).
# Hannah is the home household's head, in Chicago, with the default quiet hours of 9 PM until 7 AM.
class Notification::DeliveryJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @home = households(:home)
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @head = users(:head)
    @head.update!(time_zone: "Central Time (US & Canada)")
    @chicago = ActiveSupport::TimeZone[@head.time_zone]
    travel_to @chicago.local(2026, 11, 22, 18, 5)
  end

  test "a right-away email sends once with a setting" do
    @head.notification_settings.change([ %w[ weekly_preview email ] ])
    notification = weekly_preview_for(@head)

    assert_emails(1) { perform_enqueued_jobs }

    assert_equal [ "head@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal [ "email" ], notification.deliveries.pluck(:channel)
  end

  test "none without a setting, and none for a summary kind" do
    @head.notification_settings.change([ %w[ study_topic_needed email ], %w[ shared_with_you email ] ])
    preview = weekly_preview_for(@head)
    shared = @head.notify(kind: "shared_with_you", household: @home, subject: goals(:spouse_bible_reading), actor: users(:spouse), dedupe_key: "shared_with_you:1")

    assert_no_emails { perform_enqueued_jobs }

    assert_empty preview.deliveries
    assert_empty shared.deliveries, "its email waits for the daily summary"
  end

  test "none for a child, even with a setting from before they became one" do
    spouse = users(:spouse)
    spouse.notification_settings.change([ %w[ weekly_preview email ] ])
    memberships(:spouse_in_home).update!(role: :child)
    notification = weekly_preview_for(spouse)

    assert_no_emails { perform_enqueued_jobs }

    assert_empty notification.deliveries
  end

  test "it waits inside quiet hours" do
    @head.notification_settings.change([ %w[ weekly_preview email ] ])
    travel_to @chicago.local(2026, 11, 22, 22)
    notification = weekly_preview_for(@head)

    assert_no_emails { perform_enqueued_jobs }

    assert_empty notification.deliveries
    assert_enqueued_with job: Notification::DeliveryJob, args: [ notification ], at: @chicago.local(2026, 11, 23, 7)

    travel_to @chicago.local(2026, 11, 23, 7)
    assert_emails(1) { perform_enqueued_jobs }
    assert_no_enqueued_jobs
  end

  test "a retry doesn't send twice" do
    @head.notification_settings.change([ %w[ weekly_preview email ] ])
    notification = weekly_preview_for(@head)

    assert_emails(1) do
      Notification::DeliveryJob.perform_now(notification)
      Notification::DeliveryJob.perform_now(notification)
    end
  end

  test "SES throttling retries" do
    @head.notification_settings.change([ %w[ weekly_preview email ] ])
    notification = weekly_preview_for(@head)
    clear_enqueued_jobs

    [ "Throttling: Maximum sending rate exceeded.", "MaxSendingRateExceeded" ].each do |message|
      assert_no_emails { failing_with(StandardError.new(message)) { Notification::DeliveryJob.perform_now(notification) } }

      assert_empty notification.deliveries.reload, "the claim is deleted, so the retry can send"
      assert_enqueued_jobs 1, only: Notification::DeliveryJob
      clear_enqueued_jobs
    end

    assert_emails(1) { Notification::DeliveryJob.perform_now(notification) }
  end

  test "an SES server error and a timeout keep the claim and aren't retried" do
    @head.notification_settings.change([ %w[ weekly_preview email ] ])
    notification = weekly_preview_for(@head)
    clear_enqueued_jobs

    [ StandardError.new("InternalFailure: the request processing has failed"), Net::ReadTimeout.new ].each do |error|
      notification.deliveries.delete_all

      assert_no_emails do
        assert_nothing_raised { failing_with(error) { Notification::DeliveryJob.perform_now(notification) } }
      end

      assert_equal [ "email" ], notification.deliveries.reload.pluck(:channel)
      assert_no_enqueued_jobs
    end

    assert_no_emails { Notification::DeliveryJob.perform_now(notification) }
  end

  test "nothing is sent after the person leaves the household during quiet hours" do
    spouse = users(:spouse)
    spouse.update!(time_zone: "Central Time (US & Canada)")
    spouse.notification_settings.change([ %w[ weekly_preview email ] ])
    travel_to @chicago.local(2026, 11, 22, 22)
    notification = weekly_preview_for(spouse)
    perform_enqueued_jobs

    memberships(:spouse_in_home).deactivate
    travel_to @chicago.local(2026, 11, 23, 7)

    assert_no_emails { perform_enqueued_jobs }
    assert_empty notification.deliveries
    assert_no_enqueued_jobs
  end

  test "a notification deleted before the job runs sends nothing and doesn't fail the job" do
    @head.notification_settings.change([ %w[ weekly_preview email ] ])
    weekly_preview_for(@head).delete

    assert_no_emails { assert_nothing_raised { perform_enqueued_jobs } }
  end

  private
    def weekly_preview_for(user)
      user.notify(kind: "weekly_preview", household: @home, subject: @home, data: { week_of: "2026-11-23" }, dedupe_key: "weekly_preview:#{@home.id}:2026-11-23")
    end

    # The mail server refuses or drops the send, as SES would.
    def failing_with(error, &)
      NotificationMailer.stub(:deliver_mail, ->(_mail) { raise error }, &)
    end
end

# Two delivery jobs for one notification at the same moment: only the one whose claim went in sends
# (docs/design/notifications.md, Notification::Delivery). Each thread needs its own committed view of the rows, so
# this test runs outside a transaction and takes away what it made.
class Notification::DeliveryJobConcurrencyTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  self.use_transactional_tests = false

  setup do
    @head = users(:head)
    @home = households(:home)
    travel_to Time.utc(2026, 11, 22, 18)
    @head.notification_settings.change([ %w[ weekly_preview email ] ])
    @notification = @head.notify(kind: "weekly_preview", household: @home, subject: @home, data: { week_of: "2026-11-23" }, dedupe_key: "weekly_preview:#{@home.id}:2026-11-23")
  end

  teardown do
    @head.notifications.delete_all
    @head.notification_settings.delete_all
  end

  test "two jobs at once send once" do
    ready = Concurrent::CountDownLatch.new(2)
    go = Concurrent::CountDownLatch.new(1)

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          notification = Notification.find(@notification.id)
          ready.count_down
          go.wait
          Notification::DeliveryJob.perform_now(notification)
        end
      ensure
        ready.count_down # A thread that raised first still releases ready.wait; threads.each(&:value) re-raises.
      end
    end

    assert_emails 1 do
      ready.wait
      go.count_down
      threads.each(&:value)
    end
  end
end
