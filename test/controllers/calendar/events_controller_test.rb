require "test_helper"

# Adding, editing and deleting household events from the calendar's dialog (docs/design/calendar.md, The household event
# dialog). Tuesday 17 November 2026 in the home household (UTC).
class Calendar::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 17, 12)
    @home = households(:home)
  end

  test "an adult creates, edits and deletes an event" do
    sign_in identities(:spouse)

    get new_household_calendar_event_path(household_id: @home)
    assert_response :success
    assert_select "turbo-frame#calendar_event_dialog dialog[open] form[action=?]", household_calendar_events_path(household_id: @home) do
      assert_select "select[name='household_event[kind]'] option[selected][value=circuit_assembly]"
      assert_select "input[name='household_event[title]'][value='Circuit assembly']"
      assert_select "input[type=checkbox][name='household_event[all_day]'][checked]"
    end

    assert_difference -> { @home.events.count }, 1 do
      post household_calendar_events_path(household_id: @home), params: { household_event: {
        kind: "field_service", title: "Field service", all_day: "0", starts_on: "2026-11-21", starts_at: "09:30", ends_at: "11:00",
        repeat: "weekly", location: "Meet at the Kingdom Hall", note: "Bring tracts" } }, as: :turbo_stream
    end
    assert_response :success
    event = @home.events.order(:created_at).last
    assert_equal [ "field_service", "09:30", 90, "weekly", users(:spouse) ], [ event.kind, event.time_of_day.strftime("%H:%M"), event.duration_minutes, event.frequency, event.created_by ]
    assert_select "turbo-stream[action=update][target=calendar_event_dialog]"
    assert_select "turbo-stream[action=refresh]"

    get household_calendar_path(household_id: @home)
    assert_select "a.calendar-item--field-service[href=?][data-turbo-frame=calendar_event_dialog]",
                  edit_household_calendar_event_path(household_id: @home, id: event), /9:30 AM\s+Field service\s+Meet at the Kingdom Hall/

    get edit_household_calendar_event_path(household_id: @home, id: event)
    assert_select "dialog[open] form[action=?]", household_calendar_event_path(household_id: @home, id: event) do
      assert_select "input[name='household_event[starts_at]'][value='09:30']"
      assert_select "select[name='household_event[repeat]'] option[selected][value=weekly]"
    end
    assert_select "dialog form[action=?][data-turbo-confirm] button", household_calendar_event_path(household_id: @home, id: event), "Delete event"

    patch household_calendar_event_path(household_id: @home, id: event), params: { household_event: { title: "Saturday field service", all_day: "0",
      starts_on: "2026-11-21", starts_at: "09:30", ends_at: "11:30", repeat: "weekly" } }, as: :turbo_stream
    assert_response :success
    assert_equal [ "Saturday field service", 120 ], event.reload.values_at(:title, :duration_minutes)

    assert_difference -> { @home.events.count }, -1 do
      delete household_calendar_event_path(household_id: @home, id: event), as: :turbo_stream
    end
    assert_select "turbo-stream[action=refresh]"
  end

  test "without Turbo, a saved event goes back to the calendar" do
    sign_in identities(:head)

    patch household_calendar_event_path(household_id: @home, id: household_events(:co_visit)), params: { household_event: { title: "The CO's visit" } }

    assert_redirected_to household_calendar_path(household_id: @home)
    assert_equal [ "The CO's visit", 6 ], household_events(:co_visit).reload.values_at(:title, :days)
  end

  test "a child's create is refused" do
    sign_in identities(:eli)

    get new_household_calendar_event_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)

    assert_no_difference -> { Household::Event.count } do
      post household_calendar_events_path(household_id: @home), params: { household_event: { kind: "other", title: "Party", all_day: "1", starts_on: "2026-11-21" } }
    end
    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]

    delete household_calendar_event_path(household_id: @home, id: household_events(:co_visit))
    assert_redirected_to household_root_path(household_id: @home)
    assert Household::Event.exists?(household_events(:co_visit).id)
  end

  test "another household's event is a 404" do
    other = household_events(:other_field_service)

    # A 404 doesn't keep the session, so each request signs in again.
    sign_in identities(:head)
    get edit_household_calendar_event_path(household_id: @home, id: other)
    assert_response :not_found

    sign_in identities(:head)
    patch household_calendar_event_path(household_id: @home, id: other), params: { household_event: { title: "Mine now" } }
    assert_response :not_found

    sign_in identities(:head)
    delete household_calendar_event_path(household_id: @home, id: other)
    assert_response :not_found
    assert Household::Event.exists?(other.id)
  end

  test "a refused save renders the form with :unprocessable_content" do
    sign_in identities(:head)

    post household_calendar_events_path(household_id: @home), params: { household_event: { kind: "other", title: "", all_day: "0",
      starts_on: "2026-11-21", starts_at: "13:00", ends_at: "12:00", repeat: "once" } }

    assert_response :unprocessable_content
    assert_select "turbo-frame#calendar_event_dialog dialog[open] form" do
      assert_select ".FormControl-inlineValidation", text: /can't be blank/
      assert_select ".FormControl-inlineValidation", text: /must be after Starts/
    end

    patch household_calendar_event_path(household_id: @home, id: household_events(:co_visit)), params: { household_event: { title: "" } }
    assert_response :unprocessable_content
    assert_equal "Circuit overseer's visit", household_events(:co_visit).reload.title
  end

  test "Repeats is rebuilt for a new date, keeping the date's choices" do
    sign_in identities(:head)

    get new_household_calendar_event_path(household_id: @home, household_event: { starts_on: "2026-11-28", repeat: "monthly_last" })

    assert_select "turbo-frame#calendar_event_repeat select[name='household_event[repeat]']" do
      assert_select "option", 4
      assert_select "option[selected][value=monthly_last]", "Monthly on the last Saturday"
    end
  end
end
