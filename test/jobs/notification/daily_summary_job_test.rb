require "test_helper"

# The daily summary (docs/design/notifications.md, Delivery, step 3). Hannah is the home household's head, in Chicago,
# with the default quiet hours of 9 PM until 7 AM. She turns on both summary kinds' email on Saturday, November 21 at
# noon, which starts her cursor there.
class Notification::DailySummaryJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @home = households(:home)
    @head = users(:head)
    @head.update!(time_zone: "Central Time (US & Canada)")
    travel_to chicago(21, 12)
    @head.notification_settings.change([ %w[ shared_with_you email ], %w[ invitation_unaccepted email ] ])
  end

  test "one email at the end of quiet hours with that day's summary kinds" do
    @head.notification_settings.change([ %w[ shared_with_you email ], %w[ invitation_unaccepted email ], %w[ weekly_preview email ] ])
    travel_to chicago(21, 22)
    shared = goal_shared
    invitation = invitation_unaccepted
    preview = @head.notify(kind: "weekly_preview", household: @home, subject: @home, data: { week_of: "2026-11-23" }, dedupe_key: "weekly_preview:1")

    assert_no_emails { run_summaries at: chicago(22, 6, 45) }
    assert_emails(1) { run_summaries at: chicago(22, 7) }

    email = ActionMailer::Base.deliveries.last
    assert_equal [ "head@example.com" ], email.to
    assert_equal "Your Aglowy summary: 2 new", email.subject
    assert_includes email.text_part.decoded, "Sam shared a goal"
    assert_includes email.text_part.decoded, "Your invitation hasn't been accepted"
    assert_not_includes email.text_part.decoded, "Your week in"
    assert_equal [ "email" ], shared.deliveries.pluck(:channel)
    assert_equal [ "email" ], invitation.deliveries.pluck(:channel)
    assert_empty preview.deliveries, "the weekly preview isn't a summary's to send"
    assert_equal chicago(22, 7), @head.reload.summary_sent_through

    assert_no_emails { run_summaries at: chicago(22, 7, 15) }
  end

  test "quiet hours ending at 7:30 still get a summary" do
    @head.update!(quiet_hours_end: "07:30")
    goal_shared

    assert_no_emails { run_summaries at: chicago(22, 7, 15) }
    assert_emails(1) { run_summaries at: chicago(22, 7, 30) }
    assert_equal chicago(22, 7, 30), @head.reload.summary_sent_through
  end

  test "a skipped run is caught up by the next" do
    goal_shared

    assert_emails(1) { run_summaries at: chicago(22, 9, 15) }
    assert_equal chicago(22, 7), @head.reload.summary_sent_through
    assert_no_emails { run_summaries at: chicago(22, 9, 30) }
  end

  test "a notification older than 24 hours that was never sent is included" do
    travel_to chicago(17, 12)
    old = goal_shared

    assert_emails(1) { run_summaries at: chicago(22, 7) }
    assert_equal [ "email" ], old.deliveries.pluck(:channel)
  end

  test "nothing without settings or with nothing new" do
    users(:spouse).update!(time_zone: "Central Time (US & Canada)")
    users(:spouse).notify(kind: "shared_with_you", household: @home, subject: meeting_notes(:head_midweek), actor: @head, dedupe_key: "shared_with_you:1")

    assert_no_emails { run_summaries at: chicago(22, 7) }
    assert_nil users(:spouse).reload.summary_sent_through, "nobody without a summary email is looked at"
    assert_equal chicago(22, 7), @head.reload.summary_sent_through, "nothing new still moves the cursor"
  end

  test "a kind with no email setting is left out" do
    @head.notification_settings.change([ %w[ invitation_unaccepted email ] ])
    shared = goal_shared

    assert_no_emails { run_summaries at: chicago(22, 7) }
    assert_empty shared.deliveries
  end

  test "already-emailed ones are left out" do
    goal_shared
    run_summaries at: chicago(22, 7)
    travel_to chicago(22, 12)
    invitation_unaccepted

    assert_emails(1) { run_summaries at: chicago(23, 7) }

    email = ActionMailer::Base.deliveries.last
    assert_equal "Your Aglowy summary: 1 new", email.subject
    assert_not_includes email.text_part.decoded, "Sam shared a goal"
  end

  test "one from a household the person left is left out" do
    hidden = @head.notify(kind: "shared_with_you", household: households(:parents), subject: goals(:spouse_bible_reading), actor: users(:grandparent), dedupe_key: "shared_with_you:2")
    memberships(:head_in_parents).deactivate

    assert_no_emails { run_summaries at: chicago(22, 7) }
    assert_empty hidden.deliveries
  end

  test "a second job for the same quiet-hours end sends nothing, and a notification that arrived after it waits for the next summary" do
    goal_shared
    travel_to chicago(22, 7)
    assert_emails(1) { Notification::SummaryJob.perform_now(@head, chicago(22, 7)) }

    travel_to chicago(22, 7, 1)
    late = invitation_unaccepted
    assert_no_emails { Notification::SummaryJob.perform_now(@head, chicago(22, 7)) }
    assert_empty late.deliveries

    assert_emails(1) { run_summaries at: chicago(23, 7) }
    assert_equal [ "email" ], late.deliveries.reload.pluck(:channel)
  end

  test "another job moves the cursor while the first is throttled: the retry still sends those notifications, and the cursor ends at that quiet-hours end" do
    shared = goal_shared
    through = chicago(22, 7)
    travel_to through
    # While the first job is sending, a second one for the same end finds everything claimed and moves the cursor.
    throttled_after_another_job = ->(_mail) do
      Notification::SummaryJob.perform_now(@head, through)
      raise StandardError, "Throttling: Maximum sending rate exceeded."
    end

    assert_no_emails { NotificationMailer.stub(:deliver_mail, throttled_after_another_job) { Notification::SummaryJob.perform_now(@head, through) } }
    assert_equal through, @head.reload.summary_sent_through
    assert_empty shared.deliveries, "the throttled job's claims are deleted"
    assert_no_emails { Notification::DailySummaryJob.perform_now }
    assert_enqueued_jobs 1, only: Notification::SummaryJob

    travel_to chicago(22, 7, 3)
    assert_emails(1) { perform_enqueued_jobs only: Notification::SummaryJob }
    assert_equal [ "email" ], shared.deliveries.reload.pluck(:channel)
    assert_equal through, @head.reload.summary_sent_through
  end

  test "the cursor never moves backward" do
    travel_to chicago(23, 7)
    Notification::SummaryJob.perform_now(@head, chicago(23, 7))

    Notification::SummaryJob.perform_now(@head, chicago(22, 7))

    assert_equal chicago(23, 7), @head.reload.summary_sent_through
  end

  test "a throttled summary is retried and still sent" do
    shared = goal_shared
    travel_to chicago(22, 7)
    Notification::DailySummaryJob.perform_now

    assert_no_emails do
      NotificationMailer.stub(:deliver_mail, ->(_mail) { raise StandardError, "MaxSendingRateExceeded" }) { perform_enqueued_jobs only: Notification::SummaryJob }
    end
    assert_empty shared.deliveries
    assert_equal chicago(21, 12), @head.reload.summary_sent_through, "a throttled job leaves the cursor"
    assert_enqueued_jobs 1, only: Notification::SummaryJob

    assert_emails(1) { perform_enqueued_jobs only: Notification::SummaryJob }
    assert_equal chicago(22, 7), @head.reload.summary_sent_through
  end

  test "a summary that fails any other way keeps its claims, isn't retried, and moves the cursor" do
    shared = goal_shared
    travel_to chicago(22, 7)

    assert_no_emails do
      assert_nothing_raised { NotificationMailer.stub(:deliver_mail, ->(_mail) { raise Net::ReadTimeout }) { Notification::SummaryJob.perform_now(@head, chicago(22, 7)) } }
    end

    assert_equal [ "email" ], shared.deliveries.pluck(:channel)
    assert_no_enqueued_jobs only: Notification::SummaryJob
    assert_equal chicago(22, 7), @head.reload.summary_sent_through
  end

  test "a summary due while the person is in quiet hours waits, and the cursor doesn't move" do
    @head.update_column(:summary_sent_through, chicago(21, 7))
    goal_shared
    # 7:10, before any run: quiet hours move to end at 9, so the last end is yesterday's 9 AM and it's quiet now.
    travel_to chicago(22, 7, 10)
    @head.update!(quiet_hours_end: "09:00")

    assert_no_emails { run_summaries at: chicago(22, 7, 15) }
    assert_no_emails { Notification::SummaryJob.perform_now(@head, chicago(21, 9)) }
    assert_equal chicago(21, 7), @head.reload.summary_sent_through

    assert_emails(1) { run_summaries at: chicago(22, 9) }
    assert_equal chicago(22, 9), @head.reload.summary_sent_through
  end

  test "a new person's first summary comes at the next quiet-hours end after they turn on a summary email" do
    spouse = users(:spouse)
    spouse.update!(time_zone: "Central Time (US & Canada)")
    spouse.notify(kind: "shared_with_you", household: @home, subject: meeting_notes(:head_midweek), actor: @head, dedupe_key: "shared_with_you:1")
    travel_to chicago(21, 13)
    spouse.notification_settings.change([ %w[ shared_with_you email ] ])

    assert_no_emails { run_summaries at: chicago(21, 13, 15) }
    assert_emails(1) { run_summaries at: chicago(22, 7) }
    assert_equal [ "spouse@example.com" ], ActionMailer::Base.deliveries.last.to
  end

  test "a person with a summary email and no cursor is due" do
    @head.update_column(:summary_sent_through, nil)
    travel_to chicago(20, 12)
    goal_shared

    assert_emails(1) { run_summaries at: chicago(21, 12, 15) }
    assert_equal chicago(21, 7), @head.reload.summary_sent_through
  end

  test "someone who became a child gets no summary" do
    spouse = users(:spouse)
    spouse.notification_settings.change([ %w[ shared_with_you email ] ])
    shared = spouse.notify(kind: "shared_with_you", household: @home, subject: meeting_notes(:head_midweek), actor: @head, dedupe_key: "shared_with_you:1")
    memberships(:spouse_in_home).update!(role: :child)

    assert_no_emails { run_summaries at: chicago(22, 7) }
    assert_empty shared.deliveries
  end

  test "it runs every 15 minutes in production" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:send_daily_summaries)

    assert_equal "Notification::DailySummaryJob", task[:class]
    assert_equal "every 15 minutes", task[:schedule]
  end

  private
    def chicago(day, hour, minute = 0)
      ActiveSupport::TimeZone["Central Time (US & Canada)"].local(2026, 11, day, hour, minute)
    end

    def goal_shared
      @head.notify(kind: "shared_with_you", household: @home, subject: goals(:spouse_bible_reading), actor: users(:spouse), dedupe_key: "shared_with_you:1")
    end

    def invitation_unaccepted
      invitation = @home.invitations.create!(email: "grandpa@example.com", invited_by: @head)
      @head.notify(kind: "invitation_unaccepted", household: @home, subject: invitation, dedupe_key: "invitation_unaccepted:#{invitation.id}")
    end

    def run_summaries(at:)
      travel_to at
      Notification::DailySummaryJob.perform_now
      perform_enqueued_jobs only: Notification::SummaryJob
    end
end

# Two summary jobs for one person at the same moment: each claims in one insert, so only one holds the notifications
# and one summary goes out (docs/design/notifications.md, Delivery, step 3). Each thread needs its own committed view
# of the rows, so this test runs outside a transaction and puts back what it changed.
class Notification::SummaryJobConcurrencyTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  self.use_transactional_tests = false

  setup do
    @head = users(:head)
    @through = Time.utc(2026, 11, 22, 13)
    @head.update!(time_zone: "UTC", quiet_hours_end: "13:00")
    travel_to Time.utc(2026, 11, 21, 18)
    @head.notification_settings.change([ %w[ shared_with_you email ] ])
    @head.notify(kind: "shared_with_you", household: households(:home), subject: goals(:spouse_bible_reading), actor: users(:spouse), dedupe_key: "shared_with_you:1")
    travel_to @through
  end

  teardown do
    @head.notifications.delete_all
    @head.notification_settings.delete_all
    @head.update_columns(time_zone: nil, quiet_hours_end: "07:00", summary_sent_through: nil)
  end

  # A share ending deletes its notification (Notification.withdraw). The summary holds the ones it's claiming until
  # the claims are in, so the delete waits and the insert's foreign key can't fail and lose the others their summary.
  # The withdrawn one's claim goes with it; whether the summary still lists it depends on which finishes first.
  test "a notification withdrawn while the summary claims waits for the claims, and the rest are still sent" do
    travel_to @through - 1.hour
    doomed = @head.notify(kind: "shared_with_you", household: households(:home), subject: meeting_notes(:head_weekend), actor: users(:spouse), dedupe_key: "shared_with_you:2")
    travel_to @through
    claim_all = Notification::Delivery.method(:claim_all)
    withdrawal = nil
    claim_while_withdrawn = ->(ids, channel) do
      withdrawal = Thread.new { ActiveRecord::Base.connection_pool.with_connection { Notification.where(id: doomed.id).delete_all } }
      withdrawal.join(0.5)
      claim_all.call(ids, channel)
    end

    assert_emails 1 do
      Notification::Delivery.stub(:claim_all, claim_while_withdrawn) { Notification::SummaryJob.perform_now(@head, @through) }
      withdrawal.value
    end

    assert_not Notification.exists?(doomed.id), "the withdrawal went through once the claims were in"
    assert_equal 1, Notification::Delivery.email.where(notification: @head.notifications).count
  end

  test "two jobs at once for the same person send one summary, even when a new notification arrives between them" do
    ready = Concurrent::CountDownLatch.new(2)
    go = Concurrent::CountDownLatch.new(1)

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          user = User.find(@head.id)
          ready.count_down
          go.wait
          Notification::SummaryJob.perform_now(user, @through)
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

    travel_to @through + 1.minute
    late = @head.notify(kind: "shared_with_you", household: households(:home), subject: meeting_notes(:head_weekend), actor: users(:spouse), dedupe_key: "shared_with_you:2")

    assert_no_emails { Notification::SummaryJob.perform_now(@head, @through) }
    assert_empty late.deliveries, "it was created after through, so it waits for the next summary"
    assert_equal @through, @head.reload.summary_sent_through
  end
end
