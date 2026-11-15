require "test_helper"

class Members::RolesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  test "a head makes an adult a head" do
    sign_in identities(:head)

    patch household_member_role_path(household_id: households(:home), member_id: memberships(:spouse_in_home)),
          params: { membership: { role: "head" } }, as: :turbo_stream

    assert_response :success
    assert memberships(:spouse_in_home).reload.head?
    assert_select "turbo-stream[action=replace][target=?]", dom_id(memberships(:spouse_in_home))
    assert_includes response.body, "Sam Spouse is now a head."
  end

  test "the last head can't make themselves an adult, and the row says why" do
    sign_in identities(:head)

    patch household_member_role_path(household_id: households(:home), member_id: memberships(:head_in_home)),
          params: { membership: { role: "adult" } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert memberships(:head_in_home).reload.head?
    assert_select "turbo-stream[action=replace][target=?]", dom_id(memberships(:head_in_home))
    assert_select ".FormControl-inlineValidation", text: /A household needs at least one active head/
    assert_select "option[value=head][selected]"
  end

  test "a head who makes themselves an adult while another head stays goes to the household's home" do
    memberships(:spouse_in_home).update!(role: :head)
    sign_in identities(:head)

    patch household_member_role_path(household_id: households(:home), member_id: memberships(:head_in_home)),
          params: { membership: { role: "adult" } }, as: :turbo_stream

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You're now an adult in The Head Family.", flash[:notice]
    assert memberships(:head_in_home).reload.adult?
  end

  test "making a child an adult keeps their login" do
    sign_in identities(:head)
    identity = identities(:eli)

    patch household_member_role_path(household_id: households(:home), member_id: memberships(:eli_in_home)),
          params: { membership: { role: "adult" } }, as: :turbo_stream

    assert memberships(:eli_in_home).reload.adult?
    assert_equal [ identity.username, identity.encrypted_password ], [ users(:eli).identity.username, users(:eli).identity.encrypted_password ]
  end

  test "an unknown role is refused on the row" do
    sign_in identities(:head)

    patch household_member_role_path(household_id: households(:home), member_id: memberships(:spouse_in_home)),
          params: { membership: { role: "owner" } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert memberships(:spouse_in_home).reload.adult?
  end

  test "an adult is refused" do
    sign_in identities(:spouse)

    patch household_member_role_path(household_id: households(:home), member_id: memberships(:spouse_in_home)),
          params: { membership: { role: "head" } }, as: :turbo_stream

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert memberships(:spouse_in_home).reload.adult?
  end

  test "a member of another household, or one who has left, is 404" do
    sign_in identities(:head)

    patch household_member_role_path(household_id: households(:home), member_id: memberships(:outsider_in_other)),
          params: { membership: { role: "adult" } }, as: :turbo_stream
    assert_response :not_found

    sign_in identities(:head) # A raised 404 doesn't write the session cookie.
    patch household_member_role_path(household_id: households(:home), member_id: memberships(:former_in_home)),
          params: { membership: { role: "head" } }, as: :turbo_stream
    assert_response :not_found

    assert memberships(:outsider_in_other).reload.head?
    assert memberships(:former_in_home).reload.adult?
  end
end
