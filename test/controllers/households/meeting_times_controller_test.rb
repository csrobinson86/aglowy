require "test_helper"

class Households::MeetingTimesControllerTest < ActionDispatch::IntegrationTest
  MEETING_TIMES = { midweek_meeting_wday: "5", midweek_meeting_time: "19:00", weekend_meeting_wday: "0", weekend_meeting_time: "10:00" }.freeze

  test "an adult saves all four" do
    sign_in identities(:spouse)

    patch household_meeting_times_path(household_id: households(:home)), params: { household: MEETING_TIMES }

    assert_redirected_to edit_household_settings_household_path(household_id: households(:home))
    assert_equal "Meeting times saved.", flash[:notice]
    household = households(:home).reload
    assert_equal [ 5, 0 ], [ household.midweek_meeting_wday, household.weekend_meeting_wday ]
    assert_equal [ "19:00", "10:00" ], [ household.midweek_meeting_time, household.weekend_meeting_time ].map { it.strftime("%H:%M") }
  end

  test "a head saves them too" do
    sign_in identities(:head)

    patch household_meeting_times_path(household_id: households(:home)), params: { household: MEETING_TIMES }

    assert_redirected_to edit_household_settings_household_path(household_id: households(:home))
    assert households(:home).reload.meeting_times_set?
  end

  test "a missing time shows the error and saves nothing" do
    sign_in identities(:spouse)

    patch household_meeting_times_path(household_id: households(:home)), params: { household: MEETING_TIMES.merge(weekend_meeting_time: "") }

    assert_response :unprocessable_content
    assert_select "h1", "Household settings"
    assert_select "#household_weekend_meeting_time[aria-invalid=true]"
    assert_select "#household_midweek_meeting_time[value=?]", "19:00"
    assert_select "#household_midweek_meeting_wday option[selected][value=?]", "5"
    assert_select "nav a[aria-current=page]", text: "Household settings"
    assert_not households(:home).reload.meeting_times_set?
  end

  test "a head who gets it wrong still sees every section" do
    sign_in identities(:head)

    patch household_meeting_times_path(household_id: households(:home)), params: { household: MEETING_TIMES.merge(midweek_meeting_wday: "") }

    assert_response :unprocessable_content
    assert_select "#household_midweek_meeting_wday[aria-invalid=true]"
    assert_select "#household_name[value=?]", "The Head Family"
    assert_select "#members-and-roles"
  end

  test "a child is refused" do
    sign_in identities(:eli)

    patch household_meeting_times_path(household_id: households(:home)), params: { household: MEETING_TIMES }

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_not households(:home).reload.meeting_times_set?
  end

  test "a household you're not in is 404" do
    sign_in identities(:spouse)

    patch household_meeting_times_path(household_id: households(:other)), params: { household: MEETING_TIMES }

    assert_response :not_found
    assert_not households(:other).reload.meeting_times_set?
  end
end
