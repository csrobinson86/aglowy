require "test_helper"

class InvitationAcceptancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = invitations(:ana)
    @token = @invitation.generate_token_for(:acceptance)
  end

  # Tokens are bearer secrets: neither the Rails request log nor Lograge may write one (docs/design/invitations.md, Traps).
  test "GET /invitation?token=… keeps the token out of the Lograge line and the Rails request log" do
    log = StringIO.new
    lograge_logger, Lograge.logger = Lograge.logger, ActiveSupport::Logger.new(log)

    get invitation_acceptance_path(token: @token)

    assert_response :success
    assert_equal "/invitation?token=[FILTERED]", request.filtered_path

    # Lograge drops the whole query string from path (Lograge::LogSubscribers::ActionController#strip_query_string),
    # so the token can only reach its line through params, which Rails has filtered.
    line = JSON.parse(log.string.lines.grep(/"controller":"InvitationAcceptancesController"/).sole)
    assert_equal "/invitation", line["path"]
    assert_equal({ "token" => "[FILTERED]" }, line["params"])
    assert_not_includes log.string, @token
  ensure
    Lograge.logger = lograge_logger
  end

  test "a valid token shows the form, with the invitation's email read-only" do
    get invitation_acceptance_path(token: @token)

    assert_response :success
    assert_select "h1", "Join the The Head Family"
    assert_select "main", text: /Hannah Head invited you to join as an adult\./
    assert_select "form[action=?][method=post]", invitation_acceptance_path(token: @token)
    assert_select "input[name='invitation_signup[name]']"
    assert_select "input[name='invitation_signup[email]'][readonly][value=?]", "ana.ortiz@example.com"
    assert_select "input[name='invitation_signup[password]'][type=password]"
    assert_select "main", text: /This invitation works until #{@invitation.expires_on.strftime("%B %-d")}\./
  end

  test "an expired, resent or garbage token shows the invalid page with 404 and no household name" do
    resent_token = @token
    travel(1.minute) { @invitation.resend }
    expired_token = invitations(:expired).generate_token_for(:acceptance)

    [ expired_token, resent_token, "garbage" ].each do |token|
      get invitation_acceptance_path(token: token)

      assert_response :not_found
      assert_select "h1", "This invitation can't be used"
      assert_not_includes response.body, "The Head Family"
      assert_not_includes response.body, "Hannah Head"
    end
  end

  test "no token at all shows the invalid page with 404" do
    get invitation_acceptance_path

    assert_response :not_found
    assert_select "h1", "This invitation can't be used"
  end

  test "a token whose email has a login shows Sign in to accept, and signing in comes back here" do
    identities(:newcomer).update_column(:email, @invitation.email)

    get invitation_acceptance_path(token: @token)

    assert_response :success
    assert_select "a[href=?]", new_identity_session_path, text: "Sign in to accept"
    assert_select "form", count: 0
    assert_equal invitation_acceptance_path(token: @token), session["identity_return_to"]
  end

  test "creating the account signs in and lands on the household home" do
    assert_difference %w[ User.count Identity.count Membership.count ], 1 do
      post invitation_acceptance_path(token: @token), params: { invitation_signup: { name: "Ana Ortiz", password: "password123" } }
    end

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "Welcome to the The Head Family.", flash[:notice]

    follow_redirect!
    assert_response :success
  end

  test "an email in the form is ignored: the account gets the invitation's email" do
    post invitation_acceptance_path(token: @token), params: { invitation_signup: { name: "Ana Ortiz", email: "someone.else@example.com", password: "password123" } }

    assert Identity.exists?(email: "ana.ortiz@example.com")
    assert_not Identity.exists?(email: "someone.else@example.com")
  end

  test "a short password shows the form again with 422 and creates nothing" do
    assert_no_difference %w[ User.count Identity.count Membership.count Invitation.count ] do
      post invitation_acceptance_path(token: @token), params: { invitation_signup: { name: "Ana Ortiz", password: "short" } }
    end

    assert_response :unprocessable_content
    assert_select "input[name='invitation_signup[password]']:not([value])"
    assert_select "main", text: /is too short/
  end

  test "posting with a link that stopped working shows the invalid page with 404" do
    @invitation.cancel

    assert_no_difference %w[ User.count Identity.count Membership.count ] do
      post invitation_acceptance_path(token: @token), params: { invitation_signup: { name: "Ana Ortiz", password: "password123" } }
    end

    assert_response :not_found
    assert_select "h1", "This invitation can't be used"
  end

  # A cancel that commits after the controller found the invitation but before the join takes the household's lock.
  test "an invitation cancelled while the join waits for the lock shows the invalid page with 404" do
    cancel_at_lock = ->(*, payload) { Invitation.where(id: @invitation.id).delete_all if payload[:sql].match?(/FROM "households".*FOR UPDATE/) }

    assert_no_difference %w[ User.count Identity.count Membership.count ] do
      ActiveSupport::Notifications.subscribed(cancel_at_lock, "sql.active_record") do
        post invitation_acceptance_path(token: @token), params: { invitation_signup: { name: "Ana Ortiz", password: "password123" } }
      end
    end

    assert_response :not_found
    assert_select "h1", "This invitation can't be used"
  end
end
