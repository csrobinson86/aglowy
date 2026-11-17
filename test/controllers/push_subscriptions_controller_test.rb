require "test_helper"

# Turn on for this browser, and Remove (docs/design/notifications.md, Settings → Notifications, Phones and browsers).
# Both go through Current.user.push_subscriptions, so someone else's device is a 404.
class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  CHROME_ON_MAC = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

  setup { sign_in identities(:head) }

  test "create" do
    assert_difference -> { users(:head).push_subscriptions.count } do
      post household_push_subscriptions_path(household_id: households(:home)),
           params: { push_subscription: { endpoint: "https://fcm.googleapis.com/fcm/send/new-one", p256dh_key: "BNewKey", auth_key: "NewAuth", standalone: "false" } },
           headers: { "User-Agent" => CHROME_ON_MAC }
    end

    assert_redirected_to household_settings_notifications_path(household_id: households(:home))
    assert_equal "Notifications are on for this browser.", flash[:notice]
    subscription = PushSubscription.find_by!(endpoint: "https://fcm.googleapis.com/fcm/send/new-one")
    assert_equal [ users(:head), "BNewKey", "NewAuth", "Chrome on Mac" ], [ subscription.user, subscription.p256dh_key, subscription.auth_key, subscription.label ]
  end

  test "create refuses an address that isn't a push service" do
    assert_no_difference -> { PushSubscription.count } do
      post household_push_subscriptions_path(household_id: households(:home)),
           params: { push_subscription: { endpoint: "https://169.254.169.254/latest", p256dh_key: "BKey", auth_key: "Auth", standalone: "false" } }
    end

    assert_redirected_to household_settings_notifications_path(household_id: households(:home))
    assert_equal "Notifications couldn't be turned on for this browser.", flash[:alert]
  end

  test "a child turns it on too" do
    sign_in identities(:eli)

    post household_push_subscriptions_path(household_id: households(:home)),
         params: { push_subscription: { endpoint: "https://web.push.apple.com/QEliIpad", p256dh_key: "BKey", auth_key: "Auth", standalone: "true" } },
         headers: { "User-Agent" => "Mozilla/5.0 (iPad; CPU OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" }

    assert_equal [ "iPad · Aglowy on the Home Screen" ], users(:eli).push_subscriptions.pluck(:label)
  end

  test "destroy your own" do
    assert_difference -> { users(:head).push_subscriptions.count }, -1 do
      delete household_push_subscription_path(household_id: households(:home), id: push_subscriptions(:head_mac))
    end

    assert_redirected_to household_settings_notifications_path(household_id: households(:home))
    assert_equal "Chrome on Mac is removed.", flash[:notice]
  end

  test "someone else's is a 404" do
    assert_no_difference -> { PushSubscription.count } do
      delete household_push_subscription_path(household_id: households(:home), id: push_subscriptions(:spouse_android))
    end

    assert_response :not_found
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    post household_push_subscriptions_path(household_id: households(:home)),
         params: { push_subscription: { endpoint: "https://fcm.googleapis.com/fcm/send/x", p256dh_key: "BKey", auth_key: "Auth", standalone: "false" } }

    assert_response :not_found
  end
end
