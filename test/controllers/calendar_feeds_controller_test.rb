require "test_helper"

# The phone feed at /calendar/:token.ics: no session, the token is the authorization (docs/design/calendar.md, The
# phone feed, Trap 5).
class CalendarFeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @feed = users(:head).ensure_calendar_feed
  end

  test "a good token returns text/calendar without signing in" do
    get calendar_feed_path(token: @feed.token, format: :ics)

    assert_response :success
    assert_equal "text/calendar; charset=utf-8", response.headers["Content-Type"]
    assert_equal "max-age=900, private", response.headers["Cache-Control"]
    assert response.body.start_with?("BEGIN:VCALENDAR\r\n")
  end

  test "the token is filtered from the logged path" do
    paths = []
    subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") { paths << it.payload[:path] }

    get calendar_feed_path(token: @feed.token, format: :ics)

    assert_equal [ "/calendar/[FILTERED].ics" ], paths
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "an unknown token is a 404" do
    get calendar_feed_path(token: "not-a-real-token", format: :ics)

    assert_response :not_found
  end

  test "only as .ics" do
    get "/calendar/#{@feed.token}.json"

    assert_response :not_found
  end

  test "after reset, the old token is a 404" do
    old_token = @feed.token
    @feed.reset

    get calendar_feed_path(token: old_token, format: :ics)
    assert_response :not_found

    get calendar_feed_path(token: @feed.token, format: :ics)
    assert_response :success
  end
end
