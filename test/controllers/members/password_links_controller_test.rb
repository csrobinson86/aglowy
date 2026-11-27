require "test_helper"

class Members::PasswordLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @household = households(:home)
    @eli = memberships(:eli_in_home)
  end

  test "a head makes a link for Eli" do
    sign_in identities(:head)

    assert_no_changes -> { identities(:eli).reload.encrypted_password } do
      post household_member_password_link_path(household_id: @household, member_id: @eli)
    end

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_select "title", "New password link for Eli · The Head Family · Aglowy"
    assert_select "h1", "New password link for Eli"
    assert_select ".Banner", text: /A new password link for Eli is ready. The username is eli.rivera./
    assert_select "h2", "Open this link on Eli's device"

    link = css_select("input#password-link").sole["value"]
    token = Rack::Utils.parse_query(URI(link).query).fetch("token")
    assert_equal identities(:eli), Identity.find_by_token_for(:password_setup, token)
  end

  test "an adult makes a link for Eli too" do
    sign_in identities(:spouse)

    post household_member_password_link_path(household_id: @household, member_id: @eli)

    assert_response :success
  end

  test "refused for a login with an email" do
    Identity.create!(user: users(:child), email: "charlie@example.com", password: "password123", confirmed_at: Time.current)
    sign_in identities(:head)

    post household_member_password_link_path(household_id: @household, member_id: memberships(:child_in_home))

    assert_redirected_to household_root_path(household_id: @household)
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  # A link would take over the login, and with it the adult seat in the other household (#453).
  test "refused for a child who is an adult in another household" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :adult)
    sign_in identities(:spouse)

    post household_member_password_link_path(household_id: @household, member_id: @eli)

    assert_redirected_to household_root_path(household_id: @household)
    assert_equal "You can't do that in this household.", flash[:alert]
    follow_redirect!
    assert_select "input#password-link", count: 0
  end

  test "refused for a child with no login yet" do
    sign_in identities(:head)

    post household_member_password_link_path(household_id: @household, member_id: memberships(:sofia_in_home))

    assert_redirected_to household_root_path(household_id: @household)
  end

  test "refused for a child, even for their own login" do
    sign_in identities(:eli)

    post household_member_password_link_path(household_id: @household, member_id: @eli)

    assert_redirected_to household_root_path(household_id: @household)
  end

  test "a member from another household is 404" do
    sign_in identities(:head)

    post household_member_password_link_path(household_id: @household, member_id: memberships(:outsider_in_other))

    assert_response :not_found
  end
end
