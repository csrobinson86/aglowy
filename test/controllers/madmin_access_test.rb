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
end
