require "test_helper"

# A browser or phone that turned push on (docs/design/notifications.md, PushSubscription).
class PushSubscriptionTest < ActiveSupport::TestCase
  IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1"
  CHROME_ON_MAC = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
  ANDROID = "Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

  test "label for an iPhone running from the Home Screen, Chrome on a Mac, and Android" do
    assert_equal "iPhone · Aglowy on the Home Screen", subscribe(IPHONE, standalone: true).label
    assert_equal "Chrome on Mac", subscribe(CHROME_ON_MAC, standalone: false).label
    assert_equal "Chrome on Android", subscribe(ANDROID, standalone: false).label
    assert_equal "Android · Aglowy on the Home Screen", subscribe(ANDROID, standalone: true).label
  end

  test "label for other browsers and systems, and one it doesn't know" do
    assert_equal "Firefox on Windows", subscribe("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:133.0) Gecko/20100101 Firefox/133.0").label
    assert_equal "Edge on Windows", subscribe("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0").label
    assert_equal "Safari on Mac", subscribe("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15").label
    assert_equal "Chrome on Linux", subscribe("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36").label
    assert_equal "iPad · Aglowy on the Home Screen", subscribe("Mozilla/5.0 (iPad; CPU OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", standalone: true).label
    assert_equal "A browser", subscribe(nil).label
  end

  test "turning it on again updates the keys, and a shared browser moves to whoever turned it on last" do
    endpoint = push_subscriptions(:spouse_android).endpoint

    subscription = users(:head).push_subscriptions.subscribe(endpoint:, p256dh_key: "BNewP256dh", auth_key: "NewAuth", user_agent: ANDROID, standalone: false)

    assert_equal push_subscriptions(:spouse_android), subscription
    assert_equal [ users(:head), "BNewP256dh", "NewAuth", "Chrome on Android" ], [ subscription.user, subscription.p256dh_key, subscription.auth_key, subscription.label ]
    assert_not users(:spouse).push_subscriptions.exists?
  end

  test "only a push service's address is accepted" do
    [ "http://fcm.googleapis.com/fcm/send/x", "https://169.254.169.254/latest", "https://example.com/push", "not a url" ].each do |endpoint|
      assert_raises(ActiveRecord::RecordInvalid, endpoint) do
        users(:head).push_subscriptions.subscribe(endpoint:, p256dh_key: "BKey", auth_key: "Auth", user_agent: CHROME_ON_MAC, standalone: false)
      end
    end
  end

  test "the endpoint and keys are encrypted" do
    subscription = push_subscriptions(:head_mac)

    assert_equal subscription, PushSubscription.find_by(endpoint: subscription.endpoint), "deterministic, so it can be found"
    assert_not_includes subscription.ciphertext_for(:endpoint), "fcm.googleapis.com"
    assert subscription.encrypted_attribute?(:p256dh_key) && subscription.encrypted_attribute?(:auth_key)
  end

  test "the database refuses a duplicate endpoint" do
    existing = push_subscriptions(:head_mac)

    assert_raises(ActiveRecord::RecordNotUnique) do
      PushSubscription.insert!({ user_id: users(:spouse).id, endpoint: existing.endpoint, p256dh_key: "BKey", auth_key: "Auth", label: "Chrome on Mac", created_at: Time.current })
    end
  end

  test "the database refuses a label over 80 characters" do
    assert_raises(ActiveRecord::StatementInvalid) { push_subscriptions(:head_mac).update_column(:label, "x" * 81) }
  end

  private
    def subscribe(user_agent, standalone: false)
      users(:head).push_subscriptions.subscribe(endpoint: "https://fcm.googleapis.com/fcm/send/#{SecureRandom.hex}", p256dh_key: "BKey", auth_key: "Auth", user_agent:, standalone:)
    end
end
