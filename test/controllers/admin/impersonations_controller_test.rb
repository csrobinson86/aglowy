require "test_helper"

class Admin::ImpersonationsControllerTest < ActionDispatch::IntegrationTest
  test "staff can start and stop impersonating an identity" do
    sign_in identities(:staff)

    impersonate_from_madmin identities(:head)
    assert_redirected_to root_path
    assert_equal "Now impersonating head@example.com", flash[:notice]

    get "/madmin"
    assert_redirected_to root_path, "impersonating a non-staff identity should lose Madmin access"

    delete admin_impersonation_path
    assert_redirected_to "/madmin"
    assert_equal "Stopped impersonating", flash[:notice]

    get "/madmin"
    assert_response :success
  end

  test "impersonating an unconfirmed identity is refused" do
    sign_in identities(:staff)

    impersonate_from_madmin identities(:newcomer)
    assert_redirected_to "/madmin"
    assert_equal "newcomer@example.com can't sign in, so it can't be impersonated", flash[:alert]

    get "/madmin"
    assert_response :success
  end

  test "impersonating again while impersonating is refused" do
    identities(:spouse).update!(staff: true)
    sign_in identities(:staff)
    impersonate_from_madmin identities(:spouse)

    post admin_impersonation_path(identity_id: identities(:head).id)
    assert_redirected_to root_path

    delete admin_impersonation_path
    follow_redirect!
    assert_no_match "Impersonating", response.body
    assert_equal identities(:staff).email, controller.current_identity.email
  end

  test "a non-staff identity is refused" do
    sign_in identities(:head)

    post admin_impersonation_path(identity_id: identities(:spouse).id)
    assert_redirected_to root_path

    follow_redirect!
    assert_no_match "Impersonating", response.body
  end

  test "stopping without impersonating redirects home" do
    sign_in identities(:head)

    delete admin_impersonation_path

    assert_redirected_to root_path
  end

  private

  # Starts where staff do: the identity's Madmin page, submitting its Impersonate button.
  def impersonate_from_madmin(identity)
    get madmin_identity_path(identity)
    assert_response :success

    form = css_select("form").find { it.at_css("button")&.text == "Impersonate" }
    assert form, "the identity's Madmin page should have an Impersonate button"
    assert_equal admin_impersonation_path(identity_id: identity.id), form["action"]

    post form["action"]
  end
end
