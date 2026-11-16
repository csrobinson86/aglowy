require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "a signed-out visitor is sent to sign in" do
    get edit_account_path
    assert_redirected_to new_identity_session_path

    patch account_path, params: { user: { name: "Someone Else" } }
    assert_redirected_to new_identity_session_path
  end

  test "change name and time zone" do
    sign_in identities(:head)

    patch account_path, params: { user: { name: "  Hannah   Rivera ", time_zone: "Central Time (US & Canada)" } }

    assert_redirected_to edit_account_path
    assert_equal "Your profile is saved.", flash[:notice]
    assert_equal "Hannah Rivera", users(:head).reload.name
    assert_equal "Central Time (US & Canada)", users(:head).time_zone
  end

  test "the time zone can be left unset" do
    users(:head).update!(time_zone: "London")
    sign_in identities(:head)

    patch account_path, params: { user: { name: "Hannah Head", time_zone: "" } }

    assert_redirected_to edit_account_path
    assert_nil users(:head).reload.time_zone
  end

  test "a blank name or an unknown time zone shows the form again and changes nothing" do
    sign_in identities(:head)

    patch account_path, params: { user: { name: " ", time_zone: "Atlantis" } }

    assert_response :unprocessable_content
    assert_select "#user_name[aria-invalid=true]"
    assert_select "#user_time_zone[aria-invalid=true]"
    assert_equal "Hannah Head", users(:head).reload.name
  end

  test "when the profile is refused, the Appearance form still shows the saved choice" do
    users(:head).update!(appearance: "light")
    sign_in identities(:head)

    patch account_path, params: { user: { name: " " } }

    assert_response :unprocessable_content
    assert_select "input[type=radio][name='user[appearance]'][value=light][checked]"
    assert_select "input[type=radio][name='user[appearance]'][checked]", count: 1
  end

  test "the page shows its sections in the focused layout, Appearance between Profile and Signing in" do
    users(:head).update!(time_zone: "London")
    sign_in identities(:head)

    get edit_account_path

    assert_response :success
    assert_select "title", "Account settings"
    assert_select "main h1", "Account settings"
    assert_select "nav[aria-label='Main']", count: 0
    assert_select "form[action='/account'] #user_name[value='Hannah Head']"
    assert_select "#user_time_zone option[selected][value='London']"
    assert_select "form[action='/account/appearance'] input[type=radio][name='user[appearance]'][value=auto][checked]"
    assert_select "form[action='/account/sign_in'] #identity_email[value='head@example.com']"
    assert_equal [ "Profile", "Appearance", "Signing in", "My households" ], css_select("main .Box-header h2").map { it.text.strip }
  end

  test "Back to the household the person came from, kept through saving" do
    sign_in identities(:head)
    household = households(:home)

    get edit_account_path(return_to: household.id)
    assert_select "main a[href='#{household_root_path(household_id: household)}']", "Back to The Head Family"
    assert_select "form[action='#{account_path(return_to: household.id)}']"
    assert_select "form[action='#{account_sign_in_path(return_to: household.id)}']"

    patch account_path(return_to: household.id), params: { user: { name: "Hannah Head" } }
    assert_redirected_to edit_account_path(return_to: household.id)
  end

  # Never an arbitrary URL, and never a household the person isn't an active member of (the story's Traps).
  test "return_to that isn't one of the person's active households goes back to their households page" do
    sign_in identities(:former)

    [ households(:home).id, households(:other).id, "https://evil.example.com", "not-a-uuid" ].each do |return_to|
      get edit_account_path(return_to: return_to)

      assert_select "main a[href='#{households_path}']", "Back to your households"
      assert_select "form[action='/account']"
      assert_select "main a", text: /The Head Family|The Outsider Family/, count: 0
    end
  end
end
