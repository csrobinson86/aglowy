require "application_system_test_case"

# Household events on the calendar (docs/design/calendar.md, The household event dialog; frames calendar-new-event.png,
# calendar-week.png and calendar-child.png). Tuesday 17 November 2026 in the home household.
class CalendarEventsTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    households(:home).events.delete_all
    households(:home).change_meeting_times(midweek_wday: 5, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
  end

  test "a head adds a 6-day CO's visit and sees the band, then weekly field service on two Saturdays; a child sees both with no Household event in New" do
    sign_in identities(:head)
    visit household_calendar_url(household_id: households(:home))

    choose_from_menu "New", "Household event"
    within "dialog[open]" do
      assert_selector "h1", text: "Add a household event"
      select "Circuit overseer's visit", from: "Kind"
      assert_field "Title", with: "Circuit overseer's visit"
      assert_checked_field "All day"
      fill_in "Starts", with: "11/17/2026"
      fill_in "Ends", with: "11/22/2026"
      assert_no_select "Repeats"
      fill_in "Where", with: "Kingdom Hall"
      assert_accessible
      capture_screens("calendar-new-event")
      click_on "Add event"
    end

    assert_no_selector "dialog[open]"
    assert_selector ".calendar-band__item--start-2.calendar-band__item--span-6 a.calendar-item--co-visit", text: /Tue 17 – Sun 22\s+Circuit overseer's visit/

    choose_from_menu "New", "Household event"
    within "dialog[open]" do
      select "Field service", from: "Kind"
      assert_field "Title", with: "Field service"
      uncheck "All day"
      fill_in "Date", with: "11/21/2026"
      fill_in "Starts", with: "09:30AM"
      fill_in "Ends", with: "11:00AM"
      fill_in "Where", with: "Meet at the Kingdom Hall"
      select "Weekly on Saturday", from: "Repeats"
      click_on "Add event"
    end

    assert_no_selector "dialog[open]"
    assert_selector "section[aria-current=date] + section + section + section + section a.calendar-item--field-service", text: /9:30 AM\s+Field service\s+Meet at the Kingdom Hall/
    find("a[aria-label='Next week']").click
    assert_selector "h2", text: "November 23 – 29, 2026"
    assert_selector ".calendar-item--field-service", text: "Field service", count: 1

    sign_in identities(:eli)
    visit household_calendar_url(household_id: households(:home))

    assert_turbo_idle
    click_on "New"
    assert_selector "[role=menuitem]", exact_text: "My time"
    assert_no_selector "[role=menuitem]", text: "Household event"
    assert_no_link "Add household event"
    page.send_keys(:escape)
    assert_no_selector "[role=menuitem]"
    assert_selector "div.calendar-item--co-visit", text: /Tue 17 – Sun 22\s+Circuit overseer's visit\s+Kingdom Hall/
    assert_selector "div.calendar-item--field-service", text: /9:30 AM\s+Field service\s+Meet at the Kingdom Hall/
    assert_no_selector "a.calendar-item--field-service"
    assert_checked_field "Assemblies and special events"
    assert_checked_field "Field service"
    assert_checked_field "Other events"
    assert_accessible
    capture_screens("calendar-child")
  end

  test "a Repeats choice made while the date reloads is kept" do
    sign_in identities(:head)
    visit household_calendar_url(household_id: households(:home))
    choose_from_menu "New", "Household event"
    # Hold the Repeats frame's request until released, so the choice lands while it's in flight.
    execute_script(<<~JS)
      const fetch = window.fetch
      window.fetch = (url, options) => String(url).includes("household_event")
        ? new Promise(resolve => { window.releaseRepeatFrame = () => resolve(fetch(url, options)) })
        : fetch(url, options)
    JS

    within "dialog[open]" do
      fill_in "Starts", with: "11/28/2026"
      assert_selector "turbo-frame#calendar_event_repeat[busy]"
      select "Weekly on Tuesday", from: "Repeats"
      execute_script("window.releaseRepeatFrame()")

      assert_select "Repeats", with_options: [ "Monthly on the last Saturday" ], selected: "Weekly on Saturday"
    end
  end

  test "the month shows a several-day visit as one bar across its days, under the day numbers" do
    households(:home).events.create!(kind: "co_visit", title: "Circuit overseer's visit", starts_on: Date.new(2026, 11, 17), days: 6, created_by: users(:head))
    households(:home).events.create!(kind: "circuit_assembly", title: "Circuit assembly", starts_on: Date.new(2026, 11, 28), created_by: users(:head))
    sign_in identities(:head)
    visit household_calendar_url(household_id: households(:home), view: "month")

    bar = find(".calendar-band--month a.calendar-item--co-visit", text: "Circuit overseer's visit")
    tuesday = find(".calendar-month__day[aria-current=date]")
    sunday = find(".calendar-month__number[aria-label='Sunday, Nov 22']")
    assert_in_delta tuesday.rect.x, bar.rect.x, tuesday.rect.width / 2
    assert_operator bar.rect.x + bar.rect.width, :>, sunday.rect.x
    assert_operator bar.rect.y, :>, sunday.rect.y
    assert_selector ".calendar-band--month a.calendar-item--circuit-assembly", text: "Circuit assembly"
    assert_no_selector ".calendar-month__all-day a"
    assert_accessible
    capture_screens("calendar-month-events")
  end

  test "a refused save stays in the dialog with the reason; edit and delete an event" do
    event = households(:home).events.create!(kind: "other", title: "Kingdom Hall cleaning", starts_on: Date.new(2026, 11, 21),
                                             time_of_day: "13:00", duration_minutes: 120, created_by: users(:head))
    sign_in identities(:spouse)
    visit household_calendar_url(household_id: households(:home))

    choose_from_menu "New", "Household event"
    within("dialog[open]") { click_on "Cancel" }
    assert_no_selector "dialog[open]"

    click_on "Kingdom Hall cleaning"
    within "dialog[open]" do
      assert_selector "h1", text: "Edit household event"
      fill_in "Title", with: ""
      click_on "Save event"
      assert_text "Title can't be blank"
      fill_in "Title", with: "Hall cleaning"
      click_on "Save event"
    end
    assert_no_selector "dialog[open]"
    assert_selector "a.calendar-item--other", text: /1:00 PM\s+Hall cleaning/

    click_on "Hall cleaning"
    within "dialog[open]" do
      accept_confirm { click_on "Delete event" }
    end
    assert_no_selector ".calendar-item--other"
    assert_not Household::Event.exists?(event.id)
  end
end
