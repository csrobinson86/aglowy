require "test_helper"

# A person's own times, added and edited in a dialog on the calendar (docs/design/calendar.md, The "my time" dialog).
# Tuesday 17 November 2026 in the home household (UTC). Eli is a child there.
class PersonalTimesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 17, 12)
    @home = households(:home)
  end

  test "a child creates, edits and deletes their own time" do
    sign_in identities(:eli)

    get new_household_personal_time_path(household_id: @home)
    assert_response :success
    assert_select "turbo-frame#personal_time_dialog dialog[open] form[action=?]", household_personal_times_path(household_id: @home) do
      assert_select "input[type=radio][name='personal_time[kind]'][value=bible_reading][checked]"
      assert_select "input[name='personal_time[title]'][value='Daily Bible reading']"
      assert_select "input[type=checkbox][name='personal_time[wdays][]']", 7
      assert_select "input[type=hidden][name='personal_time[zone_shown]'][value=UTC]"
    end
    assert_select "p", "Your times are in UTC. Change it in Settings → Profile."
    assert_select "p", "Only you see your times. You can share them with a household in Settings → Calendar."

    assert_difference -> { users(:eli).personal_times.count }, 1 do
      post household_personal_times_path(household_id: @home), params: { personal_time: {
        kind: "bible_reading", title: "Read a Bible story", wdays: %w[ 0 1 2 3 4 5 6 ], time_of_day: "19:30", duration_minutes: "15",
        zone_shown: "UTC" } }, as: :turbo_stream
    end
    assert_response :success
    assert_select "turbo-stream[action=update][target=personal_time_dialog]"
    assert_select "turbo-stream[action=refresh]"
    time = users(:eli).personal_times.sole
    assert_equal [ "Read a Bible story", [ 0, 1, 2, 3, 4, 5, 6 ], "19:30", 15, Date.new(2026, 11, 17) ],
                 [ time.title, time.wdays, time.time_of_day.strftime("%H:%M"), time.duration_minutes, time.starts_on ]
    assert_equal "UTC", users(:eli).reload.time_zone

    get edit_household_personal_time_path(household_id: @home, id: time)
    assert_select "dialog[open] form[action=?]", household_personal_time_path(household_id: @home, id: time) do
      assert_select "input[name='personal_time[time_of_day]'][value='19:30']"
      assert_select "input[type=checkbox][name='personal_time[wdays][]'][checked]", 7
    end
    assert_select "p", text: /Your times are in/, count: 0
    assert_select "dialog form[action=?][data-turbo-confirm] button", household_personal_time_path(household_id: @home, id: time), "Delete time"

    patch household_personal_time_path(household_id: @home, id: time), params: { personal_time: { title: "", wdays: %w[ 6 ] } }, as: :turbo_stream
    assert_response :unprocessable_content
    assert_select "dialog[open]", text: /Title can't be blank/

    patch household_personal_time_path(household_id: @home, id: time), params: { personal_time: { title: "Bible story", wdays: %w[ 6 ] } }, as: :turbo_stream
    assert_response :success
    assert_equal [ "Bible story", [ 6 ] ], [ time.reload.title, time.wdays ]

    assert_difference -> { users(:eli).personal_times.count }, -1 do
      delete household_personal_time_path(household_id: @home, id: time), as: :turbo_stream
    end
    assert_select "turbo-stream[action=refresh]"
  end

  test "when the person shares with this household, the dialog says it sees the time" do
    sign_in identities(:eli)
    memberships(:eli_in_home).share_times

    get new_household_personal_time_path(household_id: @home)

    assert_select "p", "The Head Family sees this time's title and when it is."
  end

  test "without Turbo, a saved time goes back to the calendar" do
    time = spouse_time
    sign_in identities(:spouse)

    patch household_personal_time_path(household_id: @home, id: time), params: { personal_time: { title: "Morning reading" } }

    assert_redirected_to household_calendar_path(household_id: @home)
  end

  test "another person's time is a 404" do
    time = spouse_time

    # A 404 doesn't keep the session, so each request signs in again.
    sign_in identities(:head)
    get edit_household_personal_time_path(household_id: @home, id: time)
    assert_response :not_found
    sign_in identities(:head)
    patch household_personal_time_path(household_id: @home, id: time), params: { personal_time: { title: "Mine now" } }
    assert_response :not_found
    sign_in identities(:head)
    delete household_personal_time_path(household_id: @home, id: time)
    assert_response :not_found
    assert_equal "Daily Bible reading", time.reload.title
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    get new_household_personal_time_path(household_id: @home)

    assert_response :not_found
  end

  test "opens set to someone else's study is refused" do
    sign_in identities(:head)

    assert_no_difference -> { PersonalTime.count } do
      post household_personal_times_path(household_id: @home), params: { personal_time: {
        kind: "personal_study", title: "Personal study", wdays: %w[ 2 ], time_of_day: "20:30", duration_minutes: "60",
        opens_key: "PersonalStudy/#{personal_studies(:spouse_ransom).id}" } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "dialog[open]", text: /must be one of your own studies or notes/
  end

  test "the dialog offers the person's own studies and notes only" do
    sign_in identities(:head)

    get new_household_personal_time_path(household_id: @home)

    assert_select "select[name='personal_time[opens_key]']" do
      assert_select "option[value='']", "Nothing"
      assert_select "option[value=?]", "PersonalStudy/#{personal_studies(:head_suffering).id}"
      assert_select "option[value=?]", "PersonalNote/#{personal_notes(:head_daniel).id}"
      assert_select "option[value=?]", "PersonalStudy/#{personal_studies(:spouse_ransom).id}", 0
    end
  end

  private
    def spouse_time
      users(:spouse).update!(time_zone: "UTC")
      users(:spouse).personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: [ 2 ], time_of_day: "06:30")
    end
end
