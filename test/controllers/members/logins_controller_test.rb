require "test_helper"

class Members::LoginsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @household = households(:home)
    @sofia = memberships(:sofia_in_home)
  end

  test "an adult gives Sofia a login" do
    sign_in identities(:spouse)

    get new_household_member_login_path(household_id: @household, member_id: @sofia)

    assert_response :success
    assert_select "title", "Give Sofia a login · The Head Family · Aglowy"
    assert_select "h1", "Give Sofia a login"
    assert_select "label", /Username/
    assert_select "nav[aria-label='Breadcrumb'] a[href=?]", household_members_path(household_id: @household)
    assert_includes response.body, "Aglowy keeps only Sofia's name, username and password"

    assert_difference -> { Identity.count } => 1 do
      post household_member_login_path(household_id: @household, member_id: @sofia), params: { identity: { username: "sofia.rivera" } }
    end

    identity = users(:sofia).reload.identity
    assert_equal "sofia.rivera", identity.username
    assert_nil identity.email
    assert identity.confirmed?

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_select "meta[name='turbo-cache-control'][content='no-cache']"
    assert_select ".Banner", text: /Sofia's login is ready. The username is sofia.rivera./
    assert_select "h2", "Open this link on Sofia's device"
    assert_includes response.body, "The link works once, for the next 12 hours."

    link = css_select("input#password-link").sole["value"]
    assert_match %r{\Ahttp://www.example.com/password_setup\?token=}, link
    token = Rack::Utils.parse_query(URI(link).query).fetch("token")
    assert_equal identity, Identity.find_by_token_for(:password_setup, token)
    assert_select "[data-controller=clipboard] button[data-action=?]", "clipboard#copy", text: /Copy link/
  end

  test "a taken username re-renders with the error" do
    sign_in identities(:head)

    assert_no_difference -> { Identity.count } do
      post household_member_login_path(household_id: @household, member_id: @sofia), params: { identity: { username: "ELI.rivera" } }
    end

    assert_response :unprocessable_content
    assert_select "h1", "Give Sofia a login"
    assert_includes response.body, "Username has already been taken"
    assert_not_includes response.body, "password_setup?token="
  end

  # Two adults choosing one username at once both pass the uniqueness check in Ruby; the unique index stops the second.
  test "losing the race for a username re-renders with the error, not a 500" do
    sign_in identities(:head)
    uniqueness = Identity.validators_on(:username).grep(ActiveRecord::Validations::UniquenessValidator).sole
    uniqueness.define_singleton_method(:validate) { |_record| }

    assert_no_difference -> { Identity.count } do
      post household_member_login_path(household_id: @household, member_id: @sofia), params: { identity: { username: "eli.rivera" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Username has already been taken"
    assert_not_includes response.body, "password_setup?token="
  ensure
    uniqueness.singleton_class.remove_method(:validate)
  end

  test "an invalid username re-renders with the error" do
    sign_in identities(:head)

    assert_no_difference -> { Identity.count } do
      post household_member_login_path(household_id: @household, member_id: @sofia), params: { identity: { username: "s@" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Username is invalid"
  end

  test "a child is refused" do
    sign_in identities(:eli)

    get new_household_member_login_path(household_id: @household, member_id: @sofia)
    assert_redirected_to household_root_path(household_id: @household)

    assert_no_difference -> { Identity.count } do
      post household_member_login_path(household_id: @household, member_id: @sofia), params: { identity: { username: "sofia.rivera" } }
    end
    assert_redirected_to household_root_path(household_id: @household)
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "giving a login to an adult member is refused" do
    rosa = @household.add_member(name: "Rosa Rivera", role: "adult")
    sign_in identities(:head)

    get new_household_member_login_path(household_id: @household, member_id: rosa)
    assert_redirected_to household_root_path(household_id: @household)

    assert_no_difference -> { Identity.count } do
      post household_member_login_path(household_id: @household, member_id: rosa), params: { identity: { username: "rosa.rivera" } }
    end
    assert_redirected_to household_root_path(household_id: @household)
  end

  test "a child who already has a login is refused" do
    sign_in identities(:head)

    get new_household_member_login_path(household_id: @household, member_id: memberships(:eli_in_home))
    assert_redirected_to household_root_path(household_id: @household)

    assert_no_changes -> { identities(:eli).reload.username } do
      post household_member_login_path(household_id: @household, member_id: memberships(:eli_in_home)), params: { identity: { username: "eli.new" } }
    end
    assert_redirected_to household_root_path(household_id: @household)
  end

  test "a member from another household is 404" do
    sign_in identities(:head)

    get new_household_member_login_path(household_id: @household, member_id: memberships(:outsider_in_other))
    assert_response :not_found

    sign_in identities(:head) # The 404 doesn't write the session, so sign in again.
    post household_member_login_path(household_id: @household, member_id: memberships(:outsider_in_other)), params: { identity: { username: "olive.o" } }
    assert_response :not_found
  end

  test "a member who has left is 404" do
    @sofia.update_column(:active, false)
    sign_in identities(:head)

    get new_household_member_login_path(household_id: @household, member_id: @sofia)

    assert_response :not_found
  end
end
