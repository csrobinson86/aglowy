require "application_system_test_case"

# The calendar on a phone (docs/design/calendar.md, On a phone; frame phone-calendar.png): the week as a list of days,
# the CO's visit once as a band above it, one Add menu, the Show choices in a dialog, no Month control, and every
# target at least 44px. Tuesday 17 November 2026 in the home household (UTC).
class CalendarPhoneTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    households(:home).change_meeting_times(midweek_wday: 5, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    # The fixture parts are dated from the real today, so as the days pass one would land in this week. Tests add their own.
    MeetingPart.delete_all
    households(:home).events.delete_all
    households(:home).events.create!(kind: "co_visit", title: "Circuit overseer's visit", starts_on: Date.new(2026, 11, 17), days: 6, created_by: users(:head))
    households(:home).events.create!(kind: "field_service", title: "Field service", starts_on: Date.new(2026, 11, 21), time_of_day: "09:30",
                                     duration_minutes: 90, location: "Meet at the Kingdom Hall", created_by: users(:head))
    users(:head).update!(time_zone: "UTC")
    users(:head).personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: [ 0, 1, 2, 3, 4, 5, 6 ],
                                        time_of_day: "06:30", starts_on: Date.new(2026, 11, 1))
    sign_in identities(:head)
    visit root_url
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
    emulate_touch(true)
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "the week shows as days with headings" do
    visit calendar_url

    assert_selector "h2", text: "Nov 16 – 22"
    assert_selector ".calendar-week section h3", count: 7
    assert_selector "section[aria-current=date] h3", exact_text: "Today · Tuesday, November 17"
    assert_selector "section h3", exact_text: "Wednesday, November 18"
    assert_no_selector "segmented-control"
    assert_no_link "Month"

    band = find(".calendar-band", text: "Circuit overseer's visit")
    assert_selector ".calendar-band .calendar-item", count: 1
    assert_operator band.evaluate_script("this.getBoundingClientRect().bottom"), :<=, find("section[aria-current=date]").evaluate_script("this.getBoundingClientRect().top")

    within "section[aria-current=date]" do
      reading = find(".calendar-item--my-time", text: "Daily Bible reading")
      time, title, done = reading.find(".calendar-item__time"), reading.find(".calendar-item__title"), reading.find_field("Done: Daily Bible reading, Tuesday")
      assert_operator rect(time, "right"), :<, rect(title, "left"), "the time isn't left of the title"
      assert_operator rect(title, "right"), :<, rect(done, "left"), "the done box isn't right of the title"
    end
    assert_selector "section", text: /\ASaturday, November 21\n.*^9:30 AM\s+Field service\s+Meet at the Kingdom Hall/m

    all("main a, main button, main input[type=checkbox]").each { assert_touch_target it }
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
    execute_script("window.scrollTo(0, 0)")
    capture_screens("phone-calendar", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "?view=month shows that month's weeks as the list" do
    visit calendar_url(view: "month")

    assert_selector "h2", text: "November 2026"
    assert_no_selector ".calendar-month"
    assert_selector ".calendar-week section h3", count: 42
    assert_selector "section h3", exact_text: "Monday, October 26"
    assert_selector "section[aria-current=date] h3", exact_text: "Today · Tuesday, November 17"
    assert_selector ".calendar-band .calendar-item", count: 1
    assert_accessible
  end

  test "Add → Add my time opens the dialog; a child's Add has only Add my time" do
    visit calendar_url
    assert_no_link "Add household event"

    click_on "Add"
    assert_selector "[role=menuitem]", text: "Add household event"
    wait_for_animations
    all("[role=menuitem]").each { assert_touch_target it }
    find("[role=menuitem]", text: "Add my time").click

    within "dialog[open]" do
      assert_selector "h1", text: "Add my time"
      assert_field "Title", with: "Daily Bible reading"
    end

    sign_in identities(:eli)
    visit calendar_url
    click_on "Add"
    assert_selector "[role=menuitem]", text: "Add my time"
    assert_no_selector "[role=menuitem]", text: "Add household event"
  end

  test "\"Show on the calendar\" opens the Show choices; unticking Field service hides it" do
    visit calendar_url
    assert_selector ".calendar-item--field-service", text: "Field service"
    assert_no_field "Field service"

    find("button[aria-label='Show on the calendar']").click
    within "dialog[open]" do
      assert_selector "h1", text: "Show on the calendar"
      assert_checked_field "Meetings"
      wait_for_animations
      all("input[type=checkbox]").each { assert_touch_target it }
      assert_accessible
      uncheck "Field service"
    end

    assert_no_selector ".calendar-item--field-service"
    assert_no_selector "dialog[open]"
    assert_selector ".calendar-item--meeting", text: "Midweek meeting"
    find("button[aria-label='Show on the calendar']").click
    within("dialog[open]") { assert_no_checked_field "Field service" }
  end

  test "a title with no spaces wraps within its row" do
    users(:head).personal_times.create!(kind: "other", title: "W" * 80, wdays: [ 2 ], time_of_day: "08:00", starts_on: Date.new(2026, 11, 1))
    visit calendar_url

    within "section[aria-current=date]" do
      card = find(".calendar-item--my-time", text: "W" * 80)
      title_text = card.find(".calendar-item__title").evaluate_script(<<~JS)
        (() => { const range = document.createRange(); range.selectNodeContents(this); return range.getBoundingClientRect().right })()
      JS
      assert_operator title_text, :<, rect(card.find_field("Done: #{"W" * 80}, Tuesday"), "left"), "the title runs past the done box"
    end
  end

  test "tick today's reading" do
    visit calendar_url

    within "section[aria-current=date]" do
      check "Done: Daily Bible reading, Tuesday"
      assert_selector ".calendar-item--my-time.calendar-item--done"
      assert_checked_field "Done: Daily Bible reading, Tuesday"
    end
    assert_equal [ Date.new(2026, 11, 17) ], users(:head).personal_times.sole.completions.pluck(:on)
  end

  private
    def calendar_url(**params)
      household_calendar_url(household_id: households(:home), **params)
    end

    def rect(element, side)
      element.evaluate_script("this.getBoundingClientRect().#{side}")
    end
end
