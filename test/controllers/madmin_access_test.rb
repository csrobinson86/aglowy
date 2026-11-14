require "test_helper"

class MadminAccessTest < ActionDispatch::IntegrationTest
  test "staff get 200 on /madmin" do
    sign_in identities(:staff)

    get "/madmin"

    assert_response :success
  end

  test "a non-staff identity is redirected with Not authorized" do
    sign_in identities(:head)

    get "/madmin"

    assert_redirected_to root_path
    assert_equal "Not authorized", flash[:alert]
  end

  test "a visitor is redirected to sign in" do
    get "/madmin"

    assert_redirected_to new_identity_session_path
  end

  test "an identity's Madmin page doesn't contain encrypted_password" do
    sign_in identities(:staff)

    get madmin_identity_path(identities(:head))

    assert_response :success
    assert_no_match(/encrypted.password/i, response.body)
    assert_not_includes response.body, identities(:head).encrypted_password
  end

  test "staff can list households" do
    sign_in identities(:staff)

    get madmin_households_path

    assert_response :success
    assert_includes response.body, households(:home).name
    assert_includes response.body, households(:other).name
  end

  test "staff can view a household" do
    sign_in identities(:staff)

    get madmin_household_path(households(:home))

    assert_response :success
    assert_includes response.body, households(:home).time_zone
  end

  test "staff can list memberships" do
    sign_in identities(:staff)

    get madmin_memberships_path

    assert_response :success
    assert_includes response.body, memberships(:child_in_home).id
  end

  test "staff can view a membership by the person and household it joins" do
    sign_in identities(:staff)

    get madmin_membership_path(memberships(:child_in_home))

    assert_response :success
    assert_includes response.body, "Charlie Child in The Head Family"
  end

  test "households and memberships are read-only in Madmin" do
    sign_in identities(:staff)

    get madmin_household_path(households(:home))
    assert_select "a", text: "Edit", count: 0

    get madmin_membership_path(memberships(:child_in_home))
    assert_select "a", text: "Edit", count: 0
  end

  test "a non-staff identity can't list households" do
    sign_in identities(:head)

    get madmin_households_path

    assert_redirected_to root_path
    assert_equal "Not authorized", flash[:alert]
  end

  test "a non-staff identity can't list memberships" do
    sign_in identities(:head)

    get madmin_memberships_path

    assert_redirected_to root_path
    assert_equal "Not authorized", flash[:alert]
  end
end
