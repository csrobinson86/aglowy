# A person's notifications, from every household they're in (docs/design/notifications.md, Models), and the unread
# count the sidebar shows, kept live on the person's own stream, never a household's (Trap 6). Also which kinds they
# chose to get by email, their quiet hours and their daily summary, all read in their own zone (Trap 2).
module User::Notifiable
  extend ActiveSupport::Concern

  # What an email's "Turn off this email" link can turn off: a right-away kind, or the whole daily summary. Each has its
  # own token purpose, so a link for one can't turn off another.
  UNSUBSCRIBE_SCOPES = %w[ weekly_preview study_topic_needed summary ].freeze

  included do
    has_many :notifications, dependent: :delete_all
    has_many :notification_settings, dependent: :delete_all do
      # Replaces the person's settings with these [kind, channel] pairs in one transaction, keeping only what they're
      # offered. The first summary kind's email starts the summary cursor, so the first summary comes at the next
      # quiet-hours end. The person's lock makes two saves at once take turns.
      def change(pairs)
        user = proxy_association.owner
        chosen = pairs.map { |kind, channel| [ kind.to_s, channel.to_s ] } & user.notification_choices
        created_at = Time.current

        user.with_lock do
          delete_all
          # insert_all skips callbacks, so the UUIDv7 id is set here.
          insert_all(chosen.map { |kind, channel| { id: SecureRandom.uuid_v7, kind:, channel:, created_at: } }) if chosen.any?
          user.update_column(:summary_sent_through, created_at) if user.summary_sent_through.nil? && chosen.intersect?(Notification::Kind.summary_names.product([ "email" ]))
        end
        reset
      end
    end

    has_many :push_subscriptions, dependent: :delete_all do
      # Turns push on for this browser. A browser has one subscription, so turning it on again updates its keys, and
      # one that was someone else's (a family's shared iPad) moves to whoever turned it on last. create_or_find_by!
      # leans on the unique endpoint, so two clicks at once make one.
      def subscribe(endpoint:, p256dh_key:, auth_key:, user_agent:, standalone:)
        attributes = { user: proxy_association.owner, p256dh_key:, auth_key:, label: PushSubscription::Device.new(user_agent, standalone:).label }
        subscription = PushSubscription.create_or_find_by!(endpoint:) { it.assign_attributes(attributes) }
        subscription.update!(attributes)
        reset
        subscription
      end
    end

    # Signed and never stored; they don't expire, so the link in an old email still works.
    UNSUBSCRIBE_SCOPES.each { generates_token_for :"unsubscribe_#{it}" }

    # Wall-clock times in the person's own zone, so never shift them by the process zone.
    self.skip_time_zone_conversion_for_attributes = %i[ quiet_hours_start quiet_hours_end ]

    validates :quiet_hours_start, :quiet_hours_end, presence: true
    # The database checks it too (users_quiet_hours_half_hour_check); this gives a refused time a message.
    validate :quiet_hours_on_the_half_hour

    # Everyone with a summary kind's email on: the people Notification::DailySummaryJob looks at.
    scope :getting_summary_email, -> { where(id: NotificationSetting.email.where(kind: Notification::Kind.summary_names).select(:user_id)) }
  end

  class_methods do
    # The person an unsubscribe link was made for, or nil for an unknown scope or a bad or wrong-scope token.
    def find_by_unsubscribe_token(scope, token)
      find_by_token_for(:"unsubscribe_#{scope}", token) if scope.in?(UNSUBSCRIBE_SCOPES)
    end
  end

  # The only way notifications are made (Trap 1). The dedupe key makes a job that runs twice, or a second share, find the
  # first one instead of making another, and only a new one is delivered and counted. Both wait for it to commit, so a
  # caller's transaction that rolls back leaves no open page counting it.
  def notify(kind:, household:, subject:, dedupe_key:, actor: nil, data: {})
    notification = notifications.create_or_find_by!(dedupe_key:) do |new_one|
      new_one.assign_attributes(kind:, household:, subject:, actor:, data:)
    end

    if notification.previously_new_record?
      notification.deliver_later
      ActiveRecord.after_all_transactions_commit { broadcast_unread_notifications_count }
    end

    notification
  end

  # Mark all as read: every visible unread one, in one insert. One read in the meantime is skipped, not read twice.
  # insert_all skips callbacks, so the UUIDv7 id is set here; created_at too, so it follows the app's clock. FOR SHARE
  # holds them until the readings are in, so one deleted meanwhile (its share ending) can't fail the insert's foreign key.
  def read_all_notifications
    created_at = Time.current
    transaction do
      readings = notifications.visible.unread.lock("FOR SHARE OF notifications").pluck(:id).map { { id: SecureRandom.uuid_v7, notification_id: it, created_at: } }
      Notification::Reading.insert_all(readings, unique_by: :notification_id) if readings.any?
    end
    broadcast_unread_notifications_count
  end

  def unread_notifications_count
    notifications.visible.unread.count
  end

  # The kinds they can get: everyone the weekly preview and shares, a head or adult somewhere the invitation kind, a
  # head somewhere the topic kind (docs/design/notifications.md, Settings → Notifications).
  def notification_kinds
    Notification::Kind.all.select { it.offered_to?(self) }
  end

  # The [kind, channel] pairs Settings → Notifications offers them: push to everyone, children included, and email only
  # to those who can get it.
  def notification_choices
    notification_kinds.map(&:name).product(emailable? ? %w[ email push ] : %w[ push ])
  end

  # Children never get email, even with an address, and a username-only login has none (Trap 3).
  def emailable?
    identity&.email.present? && !child_somewhere?
  end

  def child_somewhere?
    memberships.active.child.exists?
  end

  def unsubscribe_token(scope)
    generate_token_for(:"unsubscribe_#{scope}")
  end

  # What an email's link turns off is what the email was: that right-away kind, or every summary kind, so the summary
  # really stops.
  def unsubscribe_from_email(scope)
    notification_settings.email.where(kind: scope == "summary" ? Notification::Kind.summary_names : scope).delete_all
  end

  # Nothing is emailed during quiet hours, which usually run over midnight. Starting and ending together is none.
  def quiet_now?(time = Time.current)
    now = time.in_time_zone(calendar_time_zone)
    at, start, finish = [ now, quiet_hours_start, quiet_hours_end ].map { it.hour * 60 + it.min }
    start <= finish ? (start...finish).cover?(at) : !(finish...start).cover?(at)
  end

  # The first time quiet hours end after this one.
  def quiet_hours_end_after(time)
    quiet_hours_ends_around(time).find { it > time }
  end

  # The last time quiet hours ended, at or before this one: what a daily summary is due for.
  def last_quiet_hours_end_before(time)
    quiet_hours_ends_around(time).reverse.find { it <= time }
  end

  # The quiet-hours end a summary is due for now, or nil: when their last one is later than the cursor (none yet counts
  # as earlier than any time), and never inside quiet hours, where it waits for them to end.
  def summary_due_through
    now = Time.current
    through = last_quiet_hours_end_before(now)
    through if (summary_sent_through.nil? || summary_sent_through < through) && !quiet_now?(now)
  end

  def send_daily_summary_later(through:)
    Notification::SummaryJob.perform_later(self, through)
  end

  # One email with every visible summary-kind notification from before through that they have email on for and that
  # hasn't been emailed (docs/design/notifications.md, Delivery, step 3). The claims go in first, in their own
  # statement, and the summary holds only the ones this call claimed, so two jobs at once send one summary. FOR SHARE
  # holds the notifications until the claims are in, so one deleted meanwhile (its share ending) can't fail the insert's
  # foreign key. Then the cursor moves forward to through, never backward, whether or not there was anything to send; a
  # throttled send raises before that, and its retry sends them.
  def send_daily_summary_now(through:)
    return if quiet_now?

    claimed = transaction do
      Notification::Delivery.claim_all(summary_notifications_before(through).lock("FOR SHARE OF notifications").pluck(:id), "email")
    end
    if claimed.any?
      Notification::Delivery.sending(claimed, "email") do
        NotificationMailer.daily_summary(self, notifications.preloaded.where(id: claimed).order(:created_at, :id)).deliver_now
      end
    end

    User.where(id:).update_all([ "summary_sent_through = GREATEST(COALESCE(summary_sent_through, '-infinity'), ?)", through ])
  end

  # Replaces the sidebar's counter and the accessible name of every Notifications link on the person's pages: the
  # desktop sidebar, the phone menu and the top bar's bell.
  def broadcast_unread_notifications_count
    count = unread_notifications_count
    Turbo::StreamsChannel.broadcast_replace_to [ self, :notifications ], targets: ".app-shell__notifications-counter", partial: "notifications/counter", locals: { count: }
    Turbo::StreamsChannel.broadcast_update_to [ self, :notifications ], targets: ".app-shell__notifications-name", partial: "notifications/name", locals: { count: }
  end

  private
    # When quiet hours end the day before, that day and the day after, in their zone, in order. Each is built from a
    # local date, never by adding hours, so a clock change doesn't move it.
    def quiet_hours_ends_around(time)
      zone = ActiveSupport::TimeZone[calendar_time_zone]
      date = time.in_time_zone(zone).to_date
      (date.prev_day..date.next_day).flat_map { quiet_hours_ends_on(it, zone) }
    end

    # Usually one. Two when the clocks go back over that time of day, so it comes twice and quiet_now? is true before
    # each. None by the clock when they go forward over it, and then zone.local moves it on to the time that exists.
    def quiet_hours_ends_on(date, zone)
      clock = Time.utc(date.year, date.month, date.day, quiet_hours_end.hour, quiet_hours_end.min)
      ends = zone.tzinfo.periods_for_local(clock).map { zone.at(clock.to_i - it.observed_utc_offset) }.sort
      ends.presence || [ zone.local(date.year, date.month, date.day, quiet_hours_end.hour, quiet_hours_end.min) ]
    end

    # No kinds at all for someone who can't get email, such as a person who became a child since turning it on.
    def summary_notifications_before(through)
      kinds = emailable? ? notification_settings.email.where(kind: Notification::Kind.summary_names).pluck(:kind) : []
      notifications.visible.not_emailed.where(kind: kinds, created_at: ...through)
    end

    def quiet_hours_on_the_half_hour
      %i[ quiet_hours_start quiet_hours_end ].each do |attribute|
        time = self[attribute]
        errors.add(attribute, "must be on the hour or the half hour") if time && !(time.min.in?([ 0, 30 ]) && time.sec.zero?)
      end
    end
end
