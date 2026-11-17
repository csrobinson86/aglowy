# A claim that a notification goes out on a channel (docs/design/notifications.md, Notification::Delivery). The claim is
# made before the send and only whoever made it sends, so two jobs at once, or a retry after a send, send once. That
# makes delivery at most once: a send that fails keeps its claim, unless the mail server refused it for throttling.
class Notification::Delivery < ApplicationRecord
  # The mail server refused the send before accepting it, so nothing went out and the job may try again.
  class Throttled < StandardError; end

  # Amazon SES's throttling errors, by name or message, whichever way the mail reaches it (its API or SMTP).
  THROTTLING = /Throttling|MaxSendingRateExceeded|Maximum sending rate exceeded/

  belongs_to :notification

  scope :email, -> { where(channel: "email") }

  # True for the one caller whose insert went in. One whose notification was deleted meanwhile claims nothing.
  def self.claim(notification, channel)
    claim_all([ notification.id ], channel).any?
  rescue ActiveRecord::InvalidForeignKey
    false
  end

  # Claims each in one insert that skips the ones already claimed, and returns the ids this caller now holds.
  # insert_all skips callbacks, so the UUIDv7 id is set here; created_at too, so it follows the app's clock.
  def self.claim_all(notification_ids, channel)
    return [] if notification_ids.empty?

    created_at = Time.current
    claims = notification_ids.map { { id: SecureRandom.uuid_v7, notification_id: it, channel:, created_at: } }
    insert_all(claims, unique_by: %i[ notification_id channel ], returning: :notification_id).rows.flatten
  end

  # Sends what the block sends under claims this caller already holds. Throttling gives the claims back and raises
  # Throttled, for the job to retry. Any other failure (a server error, a timeout, a dropped connection) may have come
  # after the server took the message, so the claims stay and nothing is retried: a lost email beats a second one.
  def self.sending(notification_ids, channel)
    yield
  rescue StandardError => error
    if THROTTLING.match?("#{error.class.name} #{error.message}")
      where(notification_id: notification_ids, channel:).delete_all
      raise Throttled, error.message
    else
      Rails.error.report(error, handled: true, context: { channel: })
    end
  end
end
