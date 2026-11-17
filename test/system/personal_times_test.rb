require "application_system_test_case"

# A person's own times on the calendar (docs/design/calendar.md, The "my time" dialog and My time's done box; frames
# calendar-new-time.png and calendar-week.png). Tuesday 17 November 2026 in the home household (UTC), with the midweek
# meeting on Friday at 7:00 PM.
class PersonalTimesTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 17, 15)
    households(:home).change_meeting_times(midweek_wday: 5, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
  end

  test "add daily Bible reading; tick today's" do
    sign_in identities(:spouse)
    visit household_calendar_url(household_id: households(:home))
    assert_text "Only you see your times."

    click_on "Add my time"
    within "dialog[open]" do
      assert_selector "h1", text: "Add my time"
      assert_checked_field "Bible reading"
      assert_field "Title", with: "Daily Bible reading"
      %w[ Mon Tue Wed Thu Fri Sat Sun ].each { assert_checked_field it }
      assert_no_select "Opens"
      fill_in "At", with: "06:30AM"
      select "15 minutes", from: "For"
      assert_text "Your times are in UTC. Change it in Settings → Profile."
      click_on "Add time"
    end

    assert_no_selector "dialog[open]"
    assert_selector ".calendar-item--my-time", text: /6:30 AM\s+Daily Bible reading/, count: 7
    assert_no_selector "section[aria-current=date] ~ section .calendar-item--my-time input[type=checkbox]"

    within "section[aria-current=date]" do
      check "Done: Daily Bible reading, Tuesday"
      assert_selector ".calendar-item--my-time.calendar-item--done"
      assert_checked_field "Done: Daily Bible reading, Tuesday"
    end
    assert_equal [ Date.new(2026, 11, 17) ], users(:spouse).personal_times.sole.completions.pluck(:on)

    within("section[aria-current=date]") { uncheck "Done: Daily Bible reading, Tuesday" }
    assert_no_selector ".calendar-item--done"

    click_on "Month"
    assert_selector ".calendar-month__day[aria-current=date]", text: "1 of my times"
  end

  test "add meeting prep on the day before the midweek meeting and open its note from the calendar" do
    sign_in identities(:head)
    visit household_calendar_url(household_id: households(:home))

    click_on "Add my time"
    within "dialog[open]" do
      choose "Meeting prep"
      assert_field "Title", with: "Meeting prep"
      assert_text "That week's meeting notes"
      %w[ Mon Tue Wed Fri Sat Sun ].each { uncheck it }
      fill_in "At", with: "07:00PM"
      select "45 minutes", from: "For"
      assert_accessible
      capture_screens("calendar-new-time")
      click_on "Add time"
    end

    assert_no_selector "dialog[open]"
    within ".calendar-item--my-time", text: "Meeting prep" do
      assert_text "7:00 PM"
      click_on "Life and Ministry notes"
    end

    note = users(:head).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 16))
    assert_current_path household_meeting_note_path(household_id: households(:home), id: note)
  end

  test "the week with times done, a time that opens a study, and editing one" do
    users(:head).update!(time_zone: "UTC")
    reading = users(:head).personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: [ 0, 1, 2, 3, 4, 5, 6 ],
                                                  time_of_day: "06:30", starts_on: Date.new(2026, 11, 1))
    reading.complete(on: Date.new(2026, 11, 16))
    reading.complete(on: Date.new(2026, 11, 17))
    users(:head).personal_times.create!(kind: "personal_study", title: "Personal study", wdays: [ 2 ], time_of_day: "20:30",
                                        duration_minutes: 60, opens: personal_studies(:head_suffering), starts_on: Date.new(2026, 11, 1))
    sign_in identities(:head)
    visit household_calendar_url(household_id: households(:home))

    assert_selector ".calendar-item--done", count: 2
    assert_checked_field "My times"
    assert_accessible
    capture_screens("calendar-week")

    within(".calendar-item--my-time", text: "Personal study") { click_on personal_studies(:head_suffering).title }
    assert_current_path household_personal_study_path(household_id: households(:home), id: personal_studies(:head_suffering))

    visit household_calendar_url(household_id: households(:home))
    within("section[aria-current=date]") { click_on "Personal study" }
    within "dialog[open]" do
      assert_selector "h1", text: "Edit my time"
      assert_select "Opens", selected: "Study: #{personal_studies(:head_suffering).title}"
      accept_confirm { click_on "Delete time" }
    end
    assert_no_selector ".calendar-item--my-time", text: "Personal study"

    uncheck "My times"
    assert_no_selector ".calendar-item--my-time"
  end
end
