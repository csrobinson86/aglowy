require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "a visitor is redirected to sign in" do
    get household_root_path(household_id: households(:home))

    assert_redirected_to new_identity_session_path
  end

  test "a member sees the household name and its active members, not the former member" do
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select "h1", "The Head Family"
    assert_select "main", text: /Hannah Head.*Head.*Sam Spouse.*Adult.*Charlie Child.*Child/m
    assert_not_includes response.body, "Frances Former"
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    get household_root_path(household_id: households(:home))

    assert_response :not_found
  end

  test "a former (inactive) member gets 404" do
    sign_in identities(:former)

    get household_root_path(household_id: households(:home))

    assert_response :not_found
  end

  test "a household_id that isn't a UUID gets 404" do
    sign_in identities(:head)

    get "/not-a-household"

    assert_response :not_found
  end
end
