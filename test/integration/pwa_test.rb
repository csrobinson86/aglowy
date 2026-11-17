require "test_helper"

# Rails' PWA, turned on for push (docs/design/notifications.md, Push): the manifest, linked from every page's head, and
# the service worker, which shows a push and opens it, and caches nothing.
class PwaTest < ActionDispatch::IntegrationTest
  test "the manifest is served" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    assert_equal "Aglowy", response.parsed_body["name"]
  end

  test "the service worker shows a push, opens its url, and caches nothing" do
    get pwa_service_worker_path(format: :js)

    assert_response :success
    assert_includes response.body, 'addEventListener("push"'
    assert_includes response.body, 'addEventListener("notificationclick"'
    assert_includes response.body, 'showNotification(title, { body, tag, icon: "/icon-192.png", data: { url } })'
    assert_not_includes response.body, "caches."
  end

  test "a household page links the manifest" do
    sign_in identities(:head)

    get household_settings_notifications_path(household_id: households(:home))

    assert_select "head link[rel=manifest][href='/manifest.json']", count: 1
  end
end
