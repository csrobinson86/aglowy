require "test_helper"

# Settings → Children: turning the meeting helper for children on or off, heads and adults (docs/design/settings.md;
# docs/design/meeting-helper.md, Pages).
class Settings::MeetingHelpersControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head turns it on and comes back to Children" do
    sign_in identities(:head)

    patch household_settings_meeting_helper_path(household_id: @home), params: { meeting_helper: { enabled: "1" } }

    assert_redirected_to household_settings_children_path(household_id: @home)
    assert_equal "Meeting helper turned on.", flash[:notice]
    assert @home.reload.meeting_helper?
  end

  test "an adult turns it on, and the row records the adult" do
    sign_in identities(:spouse)

    patch household_settings_meeting_helper_path(household_id: @home), params: { meeting_helper: { enabled: "1" } }

    assert_redirected_to household_settings_children_path(household_id: @home)
    assert_equal users(:spouse), @home.reload.meeting_helper.enabled_by
  end

  test "turning it off removes it" do
    @home.enable_meeting_helper(by: users(:head))
    sign_in identities(:spouse)

    patch household_settings_meeting_helper_path(household_id: @home), params: { meeting_helper: { enabled: "0" } }

    assert_redirected_to household_settings_children_path(household_id: @home)
    assert_equal "Meeting helper turned off.", flash[:notice]
    assert_not @home.reload.meeting_helper?
  end

  # A check box can't be invalid, so the only save that's refused is one without the field: 400, nothing changed.
  test "a save without the switch is refused and changes nothing" do
    sign_in identities(:head)

    patch household_settings_meeting_helper_path(household_id: @home), params: { meeting_helper: { other: "1" } }

    assert_response :bad_request
    assert_not @home.reload.meeting_helper?
  end

  test "a child is refused" do
    sign_in identities(:eli)

    patch household_settings_meeting_helper_path(household_id: @home), params: { meeting_helper: { enabled: "1" } }

    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_not @home.reload.meeting_helper?
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    patch household_settings_meeting_helper_path(household_id: @home), params: { meeting_helper: { enabled: "1" } }

    assert_response :not_found
    assert_not @home.reload.meeting_helper?
  end
end
