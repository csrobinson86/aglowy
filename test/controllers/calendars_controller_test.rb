require "test_helper"

# Tuesday 17 November 2026 in the home household (UTC), with the midweek meeting on Thursday at 7:00 PM and the weekend
# meeting on Sunday at 10:00 AM (docs/design/calendar.md, The page).
class CalendarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 17, 12)
    households(:home).change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
  end

  test "a member sees the week, and with view=month the month" do
    sign_in identities(:spouse)

    get household_calendar_path(household_id: households(:home))

    assert_response :success
    assert_select "title", "Calendar · The Head Family · Aglowy"
    assert_select "h1", "Calendar"
    assert_select "h2", "November 16 – 22, 2026"
    assert_select "section.calendar-day", 7
    assert_select "section.calendar-day h3", count: 7
    assert_select "section.calendar-day[aria-current=date] h3", /Tue 17/ do
      assert_select ".sr-only", "Tuesday, November 17"
    end
    assert_select "a[aria-label='Next week'][href=?]", household_calendar_path(household_id: households(:home), view: "week", date: "2026-11-23")
    assert_select "section.calendar-day", text: /Midweek meeting/ do
      assert_select "form[action=?][method=post]", household_meeting_notes_path(household_id: households(:home)) do
        assert_select "input[type=hidden][name='meeting_note[kind]'][value=midweek]"
        assert_select "input[type=hidden][name='meeting_note[week_of]'][value='2026-11-16']"
        assert_select "button.calendar-item.calendar-item--meeting", /7:00 PM\s+Midweek meeting/
      end
    end
    assert_select ".calendar-item--meeting", 2

    get household_calendar_path(household_id: households(:home), view: "month")

    assert_response :success
    assert_select "h2", "November 2026"
    assert_select ".calendar-month__day", 42
    assert_select ".calendar-month__day a[href=?]", household_calendar_path(household_id: households(:home), view: "week", date: "2026-11-02"), "2"
    assert_select "a[aria-label='Previous month'][href=?]", household_calendar_path(household_id: households(:home), view: "month", date: "2026-10-01")
    # The Thursdays and Sundays from 29 October to 6 December.
    assert_select ".calendar-item--meeting", 12
  end

  test "hide[]=meetings leaves meetings out" do
    sign_in identities(:spouse)

    get household_calendar_path(household_id: households(:home), hide: %w[ meetings ])

    assert_response :success
    assert_select ".calendar-item--meeting", 0
    assert_select "input[type=checkbox][value=meetings]:not([checked])"
    assert_select "input[type=checkbox][value=family_studies][checked]"
    assert_select "a[aria-label='Next week'][href=?]", household_calendar_path(household_id: households(:home), view: "week", date: "2026-11-23", hide: %w[ meetings ])
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    get household_calendar_path(household_id: households(:home))

    assert_response :not_found
  end

  test "the Show form's ticks become hide[] in the URL" do
    sign_in identities(:spouse)

    get household_calendar_path(household_id: households(:home), view: "month", date: "2026-11-01", show: [ "", "family_studies", "assemblies", "field_service", "other_events", "my_times" ])

    assert_redirected_to household_calendar_path(household_id: households(:home), view: "month", date: "2026-11-01", hide: %w[ meetings ])
  end

  test "a date that isn't one shows this week" do
    sign_in identities(:spouse)

    get household_calendar_path(household_id: households(:home), date: "next tuesday", view: "year")

    assert_select "h2", "November 16 – 22, 2026"

    get household_calendar_path(household_id: households(:home), date: "1" * 200)

    assert_select "h2", "November 16 – 22, 2026"
  end

  test "a study session links to its page; a later one not stored yet links to Family studies" do
    study = households(:home).schedule_family_study(topic: "Proverbs 3", frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00")
    sign_in identities(:eli)

    get household_calendar_path(household_id: households(:home))

    session_path = household_family_study_session_path(household_id: households(:home), family_study_id: study, id: study.first_session)
    assert_select "a.calendar-item.calendar-item--study[href=?]", session_path, /7:00 PM\s+Family study\s+Proverbs 3/

    get household_calendar_path(household_id: households(:home), date: "2027-09-07", view: "month")

    assert_select "a.calendar-item.calendar-item--study[href=?]", household_family_studies_path(household_id: households(:home)), minimum: 1
  end

  test "a child with the meeting helper on: the meeting on its day opens Today's meeting; another day's opens the note" do
    travel_to Time.utc(2026, 11, 19, 12)
    households(:home).enable_meeting_helper(by: users(:head))
    sign_in identities(:eli)

    get household_calendar_path(household_id: households(:home))

    assert_select "a.calendar-item--meeting[href=?]", household_todays_meeting_path(household_id: households(:home)), /Midweek meeting/
    assert_select "form[action=?] button.calendar-item--meeting", household_meeting_notes_path(household_id: households(:home)), /Weekend meeting/
  end

  test "nothing planned: heads and adults are offered Set your meeting times and Add household event, children aren't" do
    households(:home).family_studies.destroy_all
    households(:home).events.delete_all
    households(:home).update_columns(midweek_meeting_wday: nil, midweek_meeting_time: nil, weekend_meeting_wday: nil, weekend_meeting_time: nil)

    sign_in identities(:spouse)
    get household_calendar_path(household_id: households(:home))

    assert_select ".blankslate h2", "Nothing on the calendar yet."
    assert_select ".blankslate a[href=?]", household_settings_meetings_path(household_id: households(:home)), "Set your meeting times"
    assert_select ".blankslate a[href=?][data-turbo-frame=calendar_event_dialog]", new_household_calendar_event_path(household_id: households(:home)), "Add household event"
    assert_select "section.calendar-day", 7

    sign_in identities(:eli)
    get household_calendar_path(household_id: households(:home))

    assert_select ".blankslate h2", "Nothing on the calendar yet."
    assert_select ".blankslate a", 0
  end

  test "the viewer's zone differs from the household's: a muted line says whose zone the times are in" do
    sign_in identities(:spouse)
    get household_calendar_path(household_id: households(:home))
    assert_select "p", text: /the household's time zone/, count: 0

    users(:spouse).update!(time_zone: "Eastern Time (US & Canada)")
    households(:home).update!(time_zone: "Central Time (US & Canada)")
    get household_calendar_path(household_id: households(:home))

    assert_select "p.color-fg-muted", "Times are in Central Time, the household's time zone."
  end

  test "household events: heads and adults get Add household event and an edit link; a child sees the location and note, with no link" do
    households(:home).events.create!(kind: "field_service", title: "Field service", starts_on: Date.new(2026, 11, 21), time_of_day: "09:30",
                                     duration_minutes: 90, location: "Kingdom Hall", note: "Bring tracts", created_by: users(:head))

    sign_in identities(:spouse)
    get household_calendar_path(household_id: households(:home))

    assert_select "a[href=?][data-turbo-frame=calendar_event_dialog]", new_household_calendar_event_path(household_id: households(:home)), "Add household event"
    assert_select "turbo-frame#calendar_event_dialog"
    assert_select "ul.calendar-band[aria-label='All-day events'] li.calendar-band__item--start-2.calendar-band__item--span-6" do
      assert_select "a.calendar-item--co-visit[href=?]", edit_household_calendar_event_path(household_id: households(:home), id: household_events(:co_visit)), /Tue 17 – Sun 22\s+Circuit overseer's visit/
    end
    assert_select "a.calendar-item--field-service", /9:30 AM\s+Field service\s+Kingdom Hall\z/
    assert_select "input[type=checkbox][value=assemblies].calendar-show__check--assembly[checked]"
    assert_select "input[type=checkbox][value=field_service].calendar-show__check--field-service[checked]"
    assert_select "input[type=checkbox][value=other_events].calendar-show__check--other[checked]"

    get household_calendar_path(household_id: households(:home), view: "month")
    assert_select ".calendar-month__week ul.calendar-band--month[aria-label='All-day events'] li.calendar-band__item--start-2.calendar-band__item--span-6" do
      assert_select "a.calendar-item--co-visit.calendar-item--chip", "Circuit overseer's visit"
      assert_select ".sr-only", "Tue 17 – Sun 22"
    end
    assert_select "ul.calendar-band--month", 1
    assert_select ".calendar-month__day .calendar-month__all-day a.calendar-item--co-visit.calendar-item--chip", 6

    sign_in identities(:eli)
    get household_calendar_path(household_id: households(:home))

    assert_select "a", text: "Add household event", count: 0
    assert_select "a.calendar-item--field-service", 0
    assert_select "div.calendar-item--field-service", /9:30 AM\s+Field service\s+Kingdom Hall\s+Bring tracts/
    assert_select "div.calendar-item--co-visit", /Circuit overseer's visit/
  end
end
