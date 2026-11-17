require "test_helper"

# The phone feed, written by hand in RFC 5545 (docs/design/calendar.md, The phone feed). Gloria Grandparent is a head in
# the Grandparent Family, in Chicago: a weekly family study on Tuesdays at 7:00 PM, the midweek meeting on Thursday at
# 7:00 PM and the weekend meeting on Sunday at 10:00 AM. Monday 16 November 2026.
class CalendarFeed::DocumentTest < ActiveSupport::TestCase
  CHICAGO = "Central Time (US & Canada)"

  setup do
    travel_to Time.utc(2026, 11, 16, 12)
    @person = users(:grandparent)
    @person.update!(time_zone: CHICAGO)
    @household = households(:parents)
    @household.update!(time_zone: CHICAGO)
    @household.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @study = @household.schedule_family_study(topic: "Proverbs 3", frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00")
    @reading = @person.personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: [ 3 ], time_of_day: "06:30",
                                              starts_on: Date.new(2026, 11, 1))
  end

  test "a meeting, an all-day several-day event, a session and an own time, each as a VEVENT" do
    visit = add_event(kind: "co_visit", title: "Circuit overseer's visit", starts_on: Date.new(2026, 11, 17), days: 6, location: "Kingdom Hall")

    assert_includes vevents, [ "UID:meeting-#{@household.id}-midweek-2026-11-19@aglowy", "DTSTAMP:20261116T120000Z",
                               "DTSTART:20261120T010000Z", "DTEND:20261120T030000Z", "SUMMARY:Midweek meeting · The Grandparent Family" ]
    assert_includes vevents, [ "UID:event-#{visit.id}-2026-11-17@aglowy", "DTSTAMP:20261116T120000Z", "DTSTART;VALUE=DATE:20261117",
                               "DTEND;VALUE=DATE:20261123", "SUMMARY:Circuit overseer's visit · The Grandparent Family", "LOCATION:Kingdom Hall" ]
    assert_includes vevents, [ "UID:study-#{@study.id}-2026-11-17@aglowy", "DTSTAMP:20261116T120000Z", "DTSTART:20261118T010000Z",
                               "DTEND:20261118T020000Z", "SUMMARY:Family study · The Grandparent Family" ]
    assert_equal [ "UID:time-#{@reading.id}-2026-11-18@aglowy", "DTSTAMP:20261116T120000Z", "DTSTART:20261118T123000Z",
                   "DTEND:20261118T130000Z", "SUMMARY:Daily Bible reading" ], vevent("time-#{@reading.id}-2026-11-18").first(5)
  end

  test "an own time has a VALARM with a DESCRIPTION equal to its title; a household item has none" do
    assert_equal [ "BEGIN:VALARM", "ACTION:DISPLAY", "TRIGGER:PT0M", "DESCRIPTION:Daily Bible reading", "END:VALARM" ],
                 vevent("time-#{@reading.id}-2026-11-18").drop(5)
    assert_not_includes vevent("meeting-#{@household.id}-midweek-2026-11-19"), "BEGIN:VALARM"
  end

  test "a weekly study appears 150 days ahead, past the stored sessions" do
    travel_to Time.utc(2027, 5, 29, 12)
    tuesday = Date.new(2027, 10, 26)
    assert_operator @study.sessions.maximum(:recurrence_at), :<, tuesday

    assert_includes vevent("study-#{@study.id}-2027-10-26"), "DTSTART:20271027T000000Z"
  end

  test "a study occurrence's UID is the same before and after its session is stored, and after it moves" do
    travel_to Time.utc(2027, 6, 1, 12)
    uid = "study-#{@study.id}-2027-09-07"
    assert_includes vevent(uid), "DTSTART:20270908T000000Z"

    @study.extend_sessions(through: Date.new(2027, 9, 30))
    session = @study.sessions.find_by!(recurrence_at: Time.find_zone(CHICAGO).local(2027, 9, 7, 19))
    assert_includes vevent(uid), "DTSTART:20270908T000000Z"

    session.update!(scheduled_at: Time.find_zone(CHICAGO).local(2027, 9, 8, 18))
    assert_includes vevent(uid), "DTSTART:20270908T230000Z"
    assert_equal 1, vevents.count { it.first == "UID:#{uid}@aglowy" }
  end

  test "another member's shared time isn't in it" do
    users(:head).update!(time_zone: CHICAGO)
    users(:head).personal_times.create!(kind: "personal_study", title: "Hannah's study", wdays: [ 0, 1, 2, 3, 4, 5, 6 ], time_of_day: "08:00")
    memberships(:head_in_parents).share_times

    assert_no_match "Hannah's study", ics
  end

  test "a title with a comma and a semicolon is escaped" do
    cleaning = add_event(kind: "other", title: "Cleaning, windows; floors \\ doors", starts_on: Date.new(2026, 11, 21))

    assert_includes vevent("event-#{cleaning.id}-2026-11-21"), "SUMMARY:Cleaning\\, windows\\; floors \\\\ doors · The Grandparent Family"
  end

  test "a long line is folded at 75 octets, between characters, and every line ends with CRLF" do
    place = "Salón del Reino, Avenida de los Insurgentes Sur número 1234, Colonia del Valle, Ciudad de México, México"
    hall = add_event(kind: "field_service", title: "Field service", starts_on: Date.new(2026, 11, 21), time_of_day: "09:30", duration_minutes: 90, location: place)
    lines = ics.split("\r\n")

    assert lines.all? { it.bytesize <= 75 && it.valid_encoding? }
    assert lines.any? { it.start_with?(" ") }
    assert_includes vevent("event-#{hall.id}-2026-11-21"), "LOCATION:#{place.gsub(",", "\\,")}"
    assert ics.end_with?("END:VCALENDAR\r\n")
    assert_no_match(/(?<!\r)\n/, ics)
  end

  test "no DESCRIPTION inside any VEVENT outside its VALARM, and no URL anywhere" do
    add_event(kind: "other", title: "Kingdom Hall cleaning", starts_on: Date.new(2026, 11, 21), note: "Bring gloves")
    note = @person.personal_notes.create!(title: "Faith")
    @person.personal_times.create!(kind: "personal_study", title: "Personal study", wdays: [ 5 ], time_of_day: "20:00", opens: note)

    vevents.each do |lines|
      assert_empty lines.slice_before("BEGIN:VALARM").first.grep(/\ADESCRIPTION/)
    end
    assert_no_match(/^URL/, ics)
    assert_no_match "Bring gloves", ics
    assert_no_match "Faith", ics
  end

  test "from 30 days back to 180 days ahead, in every active household the person is in" do
    @reading.update!(wdays: [ 0, 1, 2, 3, 4, 5, 6 ], starts_on: Date.new(2026, 10, 1))
    dates = vevents.filter_map { it.find { it.start_with?("DTSTART") }&.then { Date.parse(it[/\d{8}/]) } }

    assert_equal Date.new(2026, 10, 17), dates.min
    assert_equal Date.new(2027, 5, 15), dates.max
    assert_includes ics, "SUMMARY:Weekend meeting · The Grandparent Family"
    assert_no_match "The Head Family", ics
  end

  private
    def ics
      CalendarFeed::Document.new(@person).to_s
    end

    # Each VEVENT's lines, unfolded, between BEGIN:VEVENT and END:VEVENT.
    def vevents
      ics.gsub("\r\n ", "").split("\r\n").slice_before("BEGIN:VEVENT").drop(1).map { it.drop(1).take_while { it != "END:VEVENT" } }
    end

    def vevent(uid)
      vevents.find { it.first == "UID:#{uid}@aglowy" } or flunk "No VEVENT #{uid}"
    end

    def add_event(**attributes)
      @household.events.create!(created_by: @person, **attributes)
    end
end
