require "test_helper"

class Accounts::AppearancesControllerTest < ActionDispatch::IntegrationTest
  test "choosing dark saves it and redirects to account settings with the notice, keeping return_to" do
    sign_in identities(:head)

    patch account_appearance_path(return_to: households(:home).id), params: { user: { appearance: "dark" } }

    assert_redirected_to edit_account_path(return_to: households(:home).id)
    assert_equal "Your appearance is saved.", flash[:notice]
    assert_equal "dark", users(:head).reload.appearance
  end

  test "a return_to that isn't one of the person's households is dropped" do
    sign_in identities(:head)

    patch account_appearance_path(return_to: households(:other).id), params: { user: { appearance: "light" } }

    assert_redirected_to edit_account_path
    assert_equal "light", users(:head).reload.appearance
  end

  test "an invalid value re-renders account settings with 422 and saves nothing" do
    sign_in identities(:head)

    patch account_appearance_path, params: { user: { appearance: "sepia" } }

    assert_response :unprocessable_content
    assert_select "main h1", "Account settings"
    assert_select "main", text: /is not included in the list/
    assert_select "body[data-color-mode=auto]"
    assert_select "#user_name[value='Hannah Head']:not([aria-invalid])"
    assert_equal "auto", users(:head).reload.appearance
  end

  test "only appearance is permitted: a name sent along is ignored" do
    sign_in identities(:head)

    patch account_appearance_path, params: { user: { appearance: "dark", name: "Someone Else" } }

    assert_redirected_to edit_account_path
    assert_equal "dark", users(:head).reload.appearance
    assert_equal "Hannah Head", users(:head).name
  end

  test "a signed-out visitor is sent to sign in" do
    patch account_appearance_path, params: { user: { appearance: "dark" } }

    assert_redirected_to new_identity_session_path
  end
end
