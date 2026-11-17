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

  test "the chooser renders without the sidebar navigation" do
    sign_in identities(:head)

    get households_path

    assert_response :success
    assert_select "header a[href='/'] img[src*='aglowy-mark']", count: 1
    assert_select "main h1", text: "Your households"
    assert_select "aside", count: 0
    assert_select "nav[aria-label='Main']", count: 0
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

  test "Eli gets refused on new" do
    sign_in identities(:eli)

    get new_household_path

    assert_redirected_to root_path
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "Eli gets refused on create" do
    sign_in identities(:eli)

    assert_no_difference -> { Household.count } do
      assert_no_difference -> { Membership.count } do
        post households_path, params: { household: { name: "Eli's household", time_zone: "London" } }
      end
    end

    assert_redirected_to root_path
  end

  test "someone with no memberships yet can still start their first household" do
    assert_empty users(:staff).memberships
    sign_in identities(:staff)

    get new_household_path
    assert_response :success

    assert_difference "Household.count" do
      post households_path, params: { household: { name: "The Staff Family", time_zone: "London" } }
    end
  end

  test "the households page offers \"Create a household\" only to someone who may start one" do
    sign_in identities(:head)
    get households_path
    assert_select "main a[href='#{new_household_path}']", text: "Create a household"

    sign_in identities(:eli)
    get households_path
    assert_select "main a[href='#{new_household_path}']", count: 0
  end

  test "an invalid household re-renders with 422" do
    sign_in identities(:spouse)

    assert_no_difference "Household.count" do
      post households_path, params: { household: { name: "", time_zone: "London" } }
    end

    assert_response :unprocessable_entity
  end
end
