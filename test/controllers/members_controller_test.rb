require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  test "a head sees the add member form" do
    sign_in identities(:head)

    get new_household_member_path(household_id: households(:home))

    assert_response :success
    assert_select "form[action='#{household_members_path(household_id: households(:home))}']"
  end

  test "a head adds a child: one new User, no Identity, one child Membership" do
    sign_in identities(:head)

    assert_difference [ "User.count", "Membership.count" ], 1 do
      assert_no_difference "Identity.count" do
        post household_members_path(household_id: households(:home)), params: { member: { name: "Baby Head", role: "child" } }
      end
    end

    membership = households(:home).memberships.order(:created_at).last
    assert membership.child?
    assert_equal "Baby Head", membership.user.name
    assert_nil membership.user.identity
    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "an adult is refused with an alert and nothing is created" do
    sign_in identities(:spouse)

    assert_no_difference [ "User.count", "Membership.count" ] do
      post household_members_path(household_id: households(:home)), params: { member: { name: "Baby Head", role: "child" } }
    end

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "a blank name re-renders with 422" do
    sign_in identities(:head)

    assert_no_difference [ "User.count", "Membership.count" ] do
      post household_members_path(household_id: households(:home)), params: { member: { name: " ", role: "adult" } }
    end

    assert_response :unprocessable_content
    assert_select "option[value='adult'][selected]"
  end

  test "the head role can't be given here: 400 and nothing is created" do
    sign_in identities(:head)

    assert_no_difference [ "User.count", "Membership.count" ] do
      post household_members_path(household_id: households(:home)), params: { member: { name: "Second Head", role: "head" } }
    end

    assert_response :bad_request
  end

  test "a head of another household gets 404" do
    sign_in identities(:outsider)

    assert_no_difference "Membership.count" do
      post household_members_path(household_id: households(:home)), params: { member: { name: "Intruder", role: "adult" } }
    end

    assert_response :not_found
  end
end
