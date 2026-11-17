# A person's notifications, from every household they're in (docs/design/notifications.md, Models), and the unread
# count the sidebar shows, kept live on the person's own stream, never a household's (Trap 6).
module User::Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, dependent: :delete_all
  end

  # The only way notifications are made (Trap 1). The dedupe key makes a job that runs twice, or a second share, find the
  # first one instead of making another, and only a new one is delivered and counted.
  def notify(kind:, household:, subject:, dedupe_key:, actor: nil, data: {})
    notification = notifications.create_or_find_by!(dedupe_key:) do |new_one|
      new_one.assign_attributes(kind:, household:, subject:, actor:, data:)
    end

    if notification.previously_new_record?
      notification.deliver_later
      broadcast_unread_notifications_count
    end

    notification
  end

  # Mark all as read: every visible unread one, in one insert. One read in the meantime is skipped, not read twice.
  def read_all_notifications
    readings = notifications.visible.unread.pluck(:id).map { { notification_id: it } }
    Notification::Reading.insert_all(readings, unique_by: :notification_id) if readings.any?
    broadcast_unread_notifications_count
  end

  def unread_notifications_count
    notifications.visible.unread.count
  end

  # Replaces the sidebar's counter and the accessible name of every Notifications link on the person's pages: the
  # desktop sidebar, the phone menu and the top bar's bell.
  def broadcast_unread_notifications_count
    count = unread_notifications_count
    Turbo::StreamsChannel.broadcast_replace_to [ self, :notifications ], targets: ".app-shell__notifications-counter", partial: "notifications/counter", locals: { count: }
    Turbo::StreamsChannel.broadcast_update_to [ self, :notifications ], targets: ".app-shell__notifications-name", partial: "notifications/name", locals: { count: }
  end
end
