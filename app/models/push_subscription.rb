# A browser or phone a person turned push on for (docs/design/notifications.md, PushSubscription). The endpoint works as
# a secret and the keys are the browser's, so all three are encrypted; the endpoint deterministically, so the unique
# index holds one row per browser and it can still be found.
class PushSubscription < ApplicationRecord
  # The push services browsers subscribe through: Google's (Chrome, Edge on Android, Samsung), Mozilla's, Apple's and
  # Microsoft's. Aglowy posts to the endpoint, so anything else, such as an address inside the network, is refused.
  PUSH_SERVICES = /\A(fcm\.googleapis\.com|android\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com|[a-z0-9-]+\.notify\.windows\.com)\z/

  belongs_to :user

  encrypts :endpoint, deterministic: true
  encrypts :p256dh_key, :auth_key

  validates :p256dh_key, :auth_key, presence: true
  validate :endpoint_at_a_push_service

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # Sends one push (TTL a day). It's never retried, so a device that fails, with a 429, a 5xx or a timeout, is reported
  # and kept, and the caller goes on to the next. An expired one (404 or 410) is deleted, or it would fail forever
  # (Trap 7). The endpoint is checked again here, since a row written past validations would skip the check, and short
  # timeouts keep one slow push service from holding up the rest.
  def push(message)
    return unless at_a_push_service?

    WebPush.payload_send(message:, endpoint:, p256dh: p256dh_key, auth: auth_key, vapid: Rails.configuration.x.web_push,
                         ttl: 1.day.to_i, urgency: "normal", open_timeout: 5, read_timeout: 10)
    update_column(:last_used_at, Time.current)
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    delete
  rescue StandardError => error
    Rails.error.report(error, handled: true, context: { channel: "push" })
  end

  private
    def endpoint_at_a_push_service
      errors.add(:endpoint, "isn't a push service") unless at_a_push_service?
    end

    def at_a_push_service?
      uri = URI.parse(endpoint.to_s)
      uri.is_a?(URI::HTTPS) && PUSH_SERVICES.match?(uri.host)
    rescue URI::InvalidURIError
      false
    end
end
