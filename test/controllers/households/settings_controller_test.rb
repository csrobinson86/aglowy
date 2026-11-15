require "test_helper"

class Households::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "a head renames the household" do
    sign_in identities(:head)

    get edit_household_settings_path(household_id: households(:home))
    assert_response :success
    assert_select "h1", "Household settings"
    assert_select "#household_name[value=?]", "The Head Family"
    assert_select "#household_time_zone option[selected][value=?]", "UTC"
    assert_select "nav a[aria-current=page]", text: "Household settings"

    patch household_settings_path(household_id: households(:home)), params: { household: { name: "The Riveras", time_zone: "Central Time (US & Canada)" } }

    assert_redirected_to edit_household_settings_path(household_id: households(:home))
    assert_equal "Household settings saved.", flash[:notice]
    assert_equal [ "The Riveras", "Central Time (US & Canada)" ], [ households(:home).reload.name, households(:home).time_zone ]
  end

  test "a head changing the time zone keeps each study at the same local time" do
    sign_in identities(:head)
    session = family_study_sessions(:weekly_next)
    local = session.local_scheduled_at.strftime("%Y-%m-%d %H:%M")

    patch household_settings_path(household_id: households(:home)), params: { household: { name: "The Head Family", time_zone: "Tokyo" } }

    assert_equal local, session.reload.local_scheduled_at.strftime("%Y-%m-%d %H:%M")
    assert_equal "Tokyo", session.family_study.household.time_zone
  end

  test "a blank name or an unknown time zone shows the form again and changes nothing" do
    sign_in identities(:head)

    patch household_settings_path(household_id: households(:home)), params: { household: { name: " ", time_zone: "Atlantis" } }

    assert_response :unprocessable_content
    assert_select "#household_name[aria-invalid=true]"
    assert_select "#household_time_zone[aria-invalid=true]"
    assert_select "title", "Household settings · The Head Family · Aglowy"
    assert_equal [ "The Head Family", "UTC" ], [ households(:home).reload.name, households(:home).time_zone ]
  end

  test "a head sees every section" do
    sign_in identities(:head)

    get edit_household_settings_path(household_id: households(:home))

    assert_select "main h2", text: "Household"
    assert_select "main h2", text: "Meetings"
    assert_select "main h2", text: "Children"
    assert_select "main h2", text: "Members and roles"
    assert_select "form[action=?]", household_meeting_times_path(household_id: households(:home))
    assert_select "form[action=?]", household_meeting_helper_path(household_id: households(:home))
    assert_no_match "A head changes the household's name", response.body
  end

  test "an adult opens the page and sees Meetings but not Household or Members and roles" do
    sign_in identities(:spouse)

    get edit_household_settings_path(household_id: households(:home))

    assert_response :success
    assert_select "h1", "Household settings"
    assert_select "p", text: "A head changes the household's name, time zone and roles. Adults can set the meeting times and turn on the meeting helper for children."
    assert_select "main h2", text: "Meetings"
    assert_select "main h2", text: "Children"
    assert_select "main h2", text: "Household", count: 0
    assert_select "main h2", text: "Members and roles", count: 0
    assert_select "#household_name", count: 0
    assert_select "nav a[aria-current=page]", text: "Household settings"
  end

  test "the helper is off by default, and says nothing about who turned it on" do
    sign_in identities(:spouse)

    get edit_household_settings_path(household_id: households(:home))

    assert_select "#children input[type=checkbox][name=?]:not([checked])", "meeting_helper[enabled]"
    assert_no_match "Turned on by", response.body
  end

  test "when the helper is on, the box is ticked and says who turned it on, on the date where the household lives" do
    households(:home).update!(time_zone: "Central Time (US & Canada)")
    # 2:00 AM UTC on November 16 is still the evening of November 15 in Chicago.
    travel_to(Time.utc(2026, 11, 16, 2)) { households(:home).enable_meeting_helper(by: users(:spouse)) }
    sign_in identities(:head)

    get edit_household_settings_path(household_id: households(:home))

    assert_select "#children input[type=checkbox][name=?][checked]", "meeting_helper[enabled]"
    assert_select "#children p", text: "Turned on by Sam Spouse on November 15."
  end

  test "an adult still can't rename the household" do
    sign_in identities(:spouse)

    patch household_settings_path(household_id: households(:home)), params: { household: { name: "Taken Over", time_zone: "Tokyo" } }

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_equal [ "The Head Family", "UTC" ], [ households(:home).reload.name, households(:home).time_zone ]
  end

  test "a child is refused" do
    sign_in identities(:eli)

    get edit_household_settings_path(household_id: households(:home))
    assert_redirected_to household_root_path(household_id: households(:home))

    patch household_settings_path(household_id: households(:home)), params: { household: { name: "Taken Over", time_zone: "Tokyo" } }
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_equal [ "The Head Family", "UTC" ], [ households(:home).reload.name, households(:home).time_zone ]
  end

  test "a household you're not in is 404" do
    sign_in identities(:head)

    get edit_household_settings_path(household_id: households(:other))
    assert_response :not_found

    sign_in identities(:head) # A raised 404 doesn't write the session cookie.
    patch household_settings_path(household_id: households(:other)), params: { household: { name: "Taken Over", time_zone: "Tokyo" } }
    assert_response :not_found
    assert_equal "The Outsider Family", households(:other).reload.name
  end

  test "a signed-out visitor is sent to sign in" do
    get edit_household_settings_path(household_id: households(:home))

    assert_redirected_to new_identity_session_path
  end
end
