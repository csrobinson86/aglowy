require "test_helper"

class Households::MeetingHelpersControllerTest < ActionDispatch::IntegrationTest
  test "a head turns it on" do
    sign_in identities(:head)

    patch household_meeting_helper_path(household_id: households(:home)), params: { meeting_helper: { enabled: "1" } }

    assert_redirected_to edit_household_settings_household_path(household_id: households(:home))
    assert_equal "Meeting helper turned on.", flash[:notice]
    assert households(:home).reload.meeting_helper?
  end

  test "an adult turns it on, and the row records the adult" do
    sign_in identities(:spouse)

    patch household_meeting_helper_path(household_id: households(:home)), params: { meeting_helper: { enabled: "1" } }

    assert_redirected_to edit_household_settings_household_path(household_id: households(:home))
    assert_equal users(:spouse), households(:home).reload.meeting_helper.enabled_by
  end

  test "turning it off removes it" do
    households(:home).enable_meeting_helper(by: users(:head))
    sign_in identities(:spouse)

    patch household_meeting_helper_path(household_id: households(:home)), params: { meeting_helper: { enabled: "0" } }

    assert_redirected_to edit_household_settings_household_path(household_id: households(:home))
    assert_equal "Meeting helper turned off.", flash[:notice]
    assert_not households(:home).reload.meeting_helper?
  end

  test "a child is refused" do
    sign_in identities(:eli)

    patch household_meeting_helper_path(household_id: households(:home)), params: { meeting_helper: { enabled: "1" } }

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_not households(:home).reload.meeting_helper?
  end

  test "a household you're not in is 404" do
    sign_in identities(:spouse)

    patch household_meeting_helper_path(household_id: households(:other)), params: { meeting_helper: { enabled: "1" } }

    assert_response :not_found
    assert_not households(:other).reload.meeting_helper?
  end
end
