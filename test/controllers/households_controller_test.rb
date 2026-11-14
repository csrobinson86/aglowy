require "test_helper"

class HouseholdsControllerTest < ActionDispatch::IntegrationTest
  test "a visitor is redirected to sign in" do
    get households_path

    assert_redirected_to new_identity_session_path
  end

  test "index lists only the current user's active households" do
    memberships(:head_in_parents).update!(active: false)
    sign_in identities(:head)

    get households_path

    assert_response :success
    assert_select "main", text: /The Head Family/
    assert_select "main", text: /The Grandparent Family/, count: 0
    assert_select "main", text: /The Outsider Family/, count: 0
  end

  test "create makes the current user head and redirects to the new household" do
    sign_in identities(:spouse)

    assert_difference "Household.count" do
      post households_path, params: { household: { name: "The Spouse Family", time_zone: "London" } }
    end

    household = Household.order(:created_at).last
    assert_equal [ [ users(:spouse), "head" ] ], household.memberships.map { [ it.user, it.role ] }
    assert_equal "London", household.time_zone
    assert_redirected_to household_root_path(household_id: household)
  end

  test "an invalid household re-renders with 422" do
    sign_in identities(:spouse)

    assert_no_difference "Household.count" do
      post households_path, params: { household: { name: "", time_zone: "London" } }
    end

    assert_response :unprocessable_entity
  end
end
