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

  # Signed in: the existing-account cases (docs/design/invitations.md, "Accepting").

  test "signing in from Sign in to accept comes back to the invitation" do
    @invitation.update_column(:email, identities(:outsider).email)
    get invitation_acceptance_path(token: @token)

    post identity_session_path, params: { identity: { login: identities(:outsider).email, password: "password123" } }

    assert_redirected_to invitation_acceptance_path(token: @token)
  end

  test "signed in with the invited email shows Join the household? with Join household and Decline" do
    @invitation.update_column(:email, identities(:outsider).email)
    sign_in identities(:outsider)

    get invitation_acceptance_path(token: @token)

    assert_response :success
    assert_select "h1", "Join the The Head Family?"
    assert_select "main", text: /Hannah Head invited you to join as an adult\./
    assert_select "form[action=?] button", invitation_acceptance_path(token: @token), text: "Join household"
    assert_select "form[action=?] input[name=_method][value=delete]", invitation_acceptance_path(token: @token)
    assert_select "button", text: "Decline"
    assert_select "main", text: /Signed in as outsider@example\.com/
  end

  test "matching email joins with the invited role" do
    @invitation.update_columns(email: identities(:outsider).email, role: "head")
    sign_in identities(:outsider)

    assert_difference -> { Membership.count } => 1, -> { Invitation.count } => -1 do
      post invitation_acceptance_path(token: @token)
    end

    assert_redirected_to household_root_path(household_id: households(:home))
    membership = households(:home).memberships.find_by!(user: users(:outsider))
    assert_predicate membership, :head?
    assert_predicate membership, :active?
  end

  test "someone who left and is invited back has their membership reactivated, not duplicated, and their old meeting-note shares are still gone" do
    membership = memberships(:former_in_home)
    membership.update!(active: true)
    note = users(:former).meeting_notes.create!(kind: :midweek, week_of: Date.new(2026, 11, 16))
    note.share_with(households(:home))
    assert membership.deactivate

    @invitation.update_columns(email: identities(:former).email, role: "head")
    sign_in identities(:former)

    assert_no_difference -> { Membership.count } do
      post invitation_acceptance_path(token: @token)
    end

    assert_redirected_to household_root_path(household_id: households(:home))
    membership.reload
    assert_predicate membership, :active?
    assert_predicate membership, :head?
    assert_not MeetingNote::Sharing.exists?(meeting_note: note)
  end

  test "an active member joining just deletes the invitation, keeping their role" do
    @invitation.update_columns(email: identities(:spouse).email, role: "head")
    sign_in identities(:spouse)

    assert_difference -> { Invitation.count } => -1, -> { Membership.count } => 0 do
      post invitation_acceptance_path(token: @token)
    end

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_predicate memberships(:spouse_in_home).reload, :adult?
  end

  test "a different signed-in email can't join or decline (404)" do
    sign_in identities(:outsider)

    get invitation_acceptance_path(token: @token)

    assert_response :success
    assert_select "main", text: /This invitation is for a different email address/
    assert_select "main", text: /It was sent to a•••••@example\.com, and you're signed in as outsider@example\.com\./
    assert_select "main", text: /ask Hannah Head to send a new invitation/
    assert_not_includes response.body, "ana.ortiz"
    assert_select "button", text: "Sign out"
    assert_select "button", text: "Join household", count: 0
    assert_select "button", text: "Decline", count: 0

    assert_no_difference %w[ Membership.count Invitation.count ] do
      post invitation_acceptance_path(token: @token)
      assert_response :not_found

      delete invitation_acceptance_path(token: @token)
      assert_response :not_found
    end
  end

  test "a username-only login sees the wrong-email page and can't join" do
    sign_in identities(:eli)

    get invitation_acceptance_path(token: @token)

    assert_select "main", text: /you're signed in as eli\.rivera\./
    assert_select "button", text: "Join household", count: 0

    assert_no_difference %w[ Membership.count Invitation.count ] do
      post invitation_acceptance_path(token: @token)
    end
    assert_response :not_found
  end

  test "comparing Daniel@Example.com to daniel@example.com matches" do
    @invitation.update_column(:email, "daniel@example.com")
    identities(:outsider).update_column(:email, "Daniel@Example.com")
    sign_in identities(:outsider)

    assert_difference -> { households(:home).memberships.where(user: users(:outsider)).count } => 1 do
      post invitation_acceptance_path(token: @token)
    end

    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "double-submitting Join creates one membership" do
    @invitation.update_column(:email, identities(:outsider).email)
    sign_in identities(:outsider)

    assert_difference -> { Membership.count } => 1 do
      post invitation_acceptance_path(token: @token)
      post invitation_acceptance_path(token: @token)
    end

    assert_response :not_found
  end

  test "an invitation past expires_at shows the invalid page and can't be joined, even if its token is still within its own lifetime" do
    @invitation.update_column(:email, identities(:outsider).email)
    sign_in identities(:outsider)

    travel_to(@invitation.expires_at + 1.minute) do
      get invitation_acceptance_path(token: @token)
      assert_response :not_found
      assert_select "h1", "This invitation can't be used"

      assert_no_difference -> { Membership.count } do
        post invitation_acceptance_path(token: @token)
      end
      assert_response :not_found
    end
  end

  test "joining with the link from before a resend fails, even when the resend happens between loading the page and pressing Join" do
    @invitation.update_column(:email, identities(:outsider).email)
    sign_in identities(:outsider)
    get invitation_acceptance_path(token: @token)
    assert_response :success

    travel(1.minute) { @invitation.resend }

    assert_no_difference -> { Membership.count } do
      post invitation_acceptance_path(token: @token)
    end
    assert_response :not_found
  end

  test "the join method itself: resolve the invitation from the token, then invitation.resend, then call the join with the original token; it fails and creates no membership" do
    @invitation.update_column(:email, identities(:outsider).email)
    acceptance = InvitationAcceptance.new(token: @token, identity: identities(:outsider))
    assert acceptance.invitation

    travel(1.minute) { acceptance.invitation.resend }

    assert_no_difference -> { Membership.count } do
      assert_not acceptance.join
    end
  end

  test "an invitation cancelled while Join waits for the lock shows the invalid page with 404" do
    @invitation.update_column(:email, identities(:outsider).email)
    sign_in identities(:outsider)
    cancel_at_lock = ->(*, payload) { Invitation.where(id: @invitation.id).delete_all if payload[:sql].match?(/FROM "households".*FOR UPDATE/) }

    assert_no_difference -> { Membership.count } do
      ActiveSupport::Notifications.subscribed(cancel_at_lock, "sql.active_record") do
        post invitation_acceptance_path(token: @token)
      end
    end

    assert_response :not_found
    assert_select "h1", "This invitation can't be used"
  end

  test "Decline deletes the invitation and goes to the households page" do
    @invitation.update_column(:email, identities(:outsider).email)
    sign_in identities(:outsider)

    assert_difference -> { Invitation.count } => -1, -> { Membership.count } => 0 do
      delete invitation_acceptance_path(token: @token)
    end

    assert_redirected_to households_path
    assert_equal "Invitation declined.", flash[:notice]
  end

  test "declining with a link that stopped working shows the invalid page with 404" do
    @invitation.update_column(:email, identities(:outsider).email)
    sign_in identities(:outsider)
    cancel_at_lock = ->(*, payload) { Invitation.where(id: @invitation.id).delete_all if payload[:sql].match?(/FROM "households".*FOR UPDATE/) }

    ActiveSupport::Notifications.subscribed(cancel_at_lock, "sql.active_record") do
      delete invitation_acceptance_path(token: @token)
    end

    assert_response :not_found
    assert_select "h1", "This invitation can't be used"
  end
end
