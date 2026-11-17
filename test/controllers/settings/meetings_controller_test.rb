require "test_helper"

# Settings → Meetings: the midweek and weekend meeting times, heads and adults (docs/design/settings.md;
# docs/design/meeting-helper.md, Pages).
class Settings::MeetingsControllerTest < ActionDispatch::IntegrationTest
  MEETING_TIMES = { midweek_meeting_wday: "5", midweek_meeting_time: "19:00", weekend_meeting_wday: "0", weekend_meeting_time: "10:00" }.freeze

  setup { @home = households(:home) }

  test "a head and an adult see the Meetings section with its form" do
    %i[ head spouse ].each do |identity|
      sign_in identities(identity)

      get household_settings_meetings_path(household_id: @home)

      assert_response :success
      assert_select "title", "Meetings · Settings · The Head Family · Aglowy"
      assert_select "main h2", "Meetings"
      assert_select "main p", "The Head Family · heads and adults can change this."
      assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Meetings"
      assert_select "form[action=?] #household_midweek_meeting_wday", household_settings_meetings_path(household_id: @home)
    end
  end

  test "an adult saves all four and comes back to Meetings" do
    sign_in identities(:spouse)

    patch household_settings_meetings_path(household_id: @home), params: { household: MEETING_TIMES }

    assert_redirected_to household_settings_meetings_path(household_id: @home)
    assert_equal "Meeting times saved.", flash[:notice]
    @home.reload
    assert_equal [ 5, 0 ], [ @home.midweek_meeting_wday, @home.weekend_meeting_wday ]
    assert_equal [ "19:00", "10:00" ], [ @home.midweek_meeting_time, @home.weekend_meeting_time ].map { it.strftime("%H:%M") }
  end

  test "a head saves them too" do
    sign_in identities(:head)

    patch household_settings_meetings_path(household_id: @home), params: { household: MEETING_TIMES }

    assert_redirected_to household_settings_meetings_path(household_id: @home)
    assert @home.reload.meeting_times_set?
  end

  test "a refused save re-renders Meetings with 422, keeping what was typed" do
    sign_in identities(:spouse)

    patch household_settings_meetings_path(household_id: @home), params: { household: MEETING_TIMES.merge(weekend_meeting_time: "") }

    assert_response :unprocessable_content
    assert_select "main h2", "Meetings"
    assert_select "#household_weekend_meeting_time[aria-invalid=true]"
    assert_select "#household_midweek_meeting_time[value=?]", "19:00"
    assert_select "#household_midweek_meeting_wday option[selected][value=?]", "5"
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Meetings"
    assert_not @home.reload.meeting_times_set?
  end

  test "a child is refused, to see it or to save it" do
    sign_in identities(:eli)

    get household_settings_meetings_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)

    patch household_settings_meetings_path(household_id: @home), params: { household: MEETING_TIMES }
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_not @home.reload.meeting_times_set?
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)
    get household_settings_meetings_path(household_id: @home)
    assert_response :not_found

    sign_in identities(:outsider)
    patch household_settings_meetings_path(household_id: @home), params: { household: MEETING_TIMES }
    assert_response :not_found
    assert_not @home.reload.meeting_times_set?
  end
end
