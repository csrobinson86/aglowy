# When it exists, that kind comes to that person on that channel (docs/design/notifications.md, Models). Nothing exists
# by default, so everything beyond the inbox starts off. Changed only through user.notification_settings.change.
class NotificationSetting < ApplicationRecord
  CHANNELS = %w[ email push ].freeze

  belongs_to :user

  scope :email, -> { where(channel: "email") }
end
