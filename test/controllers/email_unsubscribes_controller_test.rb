require "test_helper"

# "Turn off this email" and the mail client's one-click POST (docs/design/notifications.md, Emails). Nobody is signed
# in: the signed token is the only authentication, and it works only for the scope it was made for.
class EmailUnsubscribesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @head = users(:head)
    @head.notification_settings.change(Notification::Kind.all.map { [ it.name, "email" ] })
  end

  test "GET shows the button without changing anything" do
    get email_unsubscribe_path(scope: "weekly_preview", token: @head.unsubscribe_token("weekly_preview"))

    assert_response :success
    assert_select "main h1", "Turn off Weekly preview emails?"
    assert_select "main form[method=post][action=?] button[type=submit]", email_unsubscribe_path(scope: "weekly_preview", token: @head.unsubscribe_token("weekly_preview")), "Turn off this email"
    assert_equal 4, @head.notification_settings.count

    get email_unsubscribe_path(scope: "summary", token: @head.unsubscribe_token("summary"))

    assert_select "main h1", "Turn off your daily summary email?"
    assert_equal 4, @head.notification_settings.count
  end

  test "POST from a right-away email turns that kind off" do
    post email_unsubscribe_path(scope: "study_topic_needed", token: @head.unsubscribe_token("study_topic_needed"))

    assert_response :success
    assert_select "main h1", "Family study needs a topic emails are off"
    assert_equal %w[ invitation_unaccepted shared_with_you weekly_preview ], @head.notification_settings.pluck(:kind).sort
  end

  test "POST from a summary turns off every summary kind" do
    post email_unsubscribe_path(scope: "summary", token: @head.unsubscribe_token("summary"))

    assert_response :success
    assert_select "main h1", "Your daily summary email is off"
    assert_equal %w[ study_topic_needed weekly_preview ], @head.notification_settings.pluck(:kind).sort
  end

  test "a one-click POST with no session and no CSRF token works" do
    with_forgery_protection do
      post email_unsubscribe_path(scope: "weekly_preview", token: @head.unsubscribe_token("weekly_preview")), params: { "List-Unsubscribe" => "One-Click" }

      assert_response :success
      assert_not @head.notification_settings.exists?(kind: "weekly_preview")
    end
  end

  # The link is a bearer secret in the path, and Lograge logs the path (docs/design/invitations.md, Traps).
  test "the token is filtered from the logged path, on the page, the POST and a refused link" do
    paths = []
    subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") { paths << it.payload[:path] }
    path = email_unsubscribe_path(scope: "weekly_preview", token: @head.unsubscribe_token("weekly_preview"))

    get path
    post path
    get "#{email_unsubscribe_path(scope: "summary", token: "nonsense")}?utm=1"

    assert_equal [ "/unsubscribe/weekly_preview/[FILTERED]", "/unsubscribe/weekly_preview/[FILTERED]", "/unsubscribe/summary/[FILTERED]?utm=1" ], paths
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "an old browser or mail client can still open the page and turn the email off" do
    old_chrome = { "User-Agent" => "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36" }
    path = email_unsubscribe_path(scope: "weekly_preview", token: @head.unsubscribe_token("weekly_preview"))

    get root_path, headers: old_chrome
    assert_response :not_acceptable, "the rest of the app still asks for a modern browser"

    get path, headers: old_chrome
    assert_response :success

    post path, headers: old_chrome
    assert_response :success
    assert_not @head.notification_settings.exists?(kind: "weekly_preview")
  end

  test "forgery protection stays on for every other form" do
    sign_in identities(:head)

    with_forgery_protection do
      patch household_settings_quiet_hours_path(household_id: households(:home)), params: { user: { quiet_hours_start: "22:00", quiet_hours_end: "06:00" } }

      assert_response :unprocessable_content
    end
  end

  test "a wrong-scope token and a bad token are refused" do
    { "summary" => @head.unsubscribe_token("weekly_preview"), "weekly_preview" => "nonsense", "shared_with_you" => @head.unsubscribe_token("summary") }.each do |scope, token|
      get email_unsubscribe_path(scope:, token:)

      assert_response :not_found
      assert_select "main", text: /This link no longer works\. Change emails in Settings → Notifications\./
      assert_select "form", count: 0

      post email_unsubscribe_path(scope:, token:)

      assert_response :not_found
      assert_select "main", text: /This link no longer works\. Change emails in Settings → Notifications\./
    end

    assert_equal 4, @head.notification_settings.count
  end

  test "a deleted person's link is refused" do
    token = users(:newcomer).unsubscribe_token("summary")
    users(:newcomer).destroy!

    post email_unsubscribe_path(scope: "summary", token:)

    assert_response :not_found
  end

  private
    def with_forgery_protection
      original, ActionController::Base.allow_forgery_protection = ActionController::Base.allow_forgery_protection, true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
end
