require "test_helper"

class TodaysMeetingsControllerTest < ActionDispatch::IntegrationTest
  # Thursday 19 November 2026, an hour before the midweek meeting; the home household is in UTC.
  setup { travel_to Time.utc(2026, 11, 19, 18) }

  test "times set, no note yet: show lists the current meeting and creates nothing" do
    set_meeting_times
    sign_in identities(:spouse)

    assert_no_difference -> { MeetingNote.count } do
      get household_todays_meeting_path(household_id: households(:home))
    end

    assert_response :success
    assert_select "title", "Today's meeting · The Head Family · Aglowy"
    assert_select "h1", "Today's meeting"
    assert_select "main .Box", text: /Midweek meeting · Thursday 7:00 PM/
    assert_select "form[action='#{household_todays_meeting_path(household_id: households(:home))}'][method=post]", count: 1 do
      assert_select "input[type=hidden][name='meeting_note[kind]'][value=midweek]"
      assert_select "input[type=hidden][name='meeting_note[week_of]'][value='2026-11-16']"
      assert_select "button", "Start my notes"
    end
  end

  test "times set, a note exists: show redirects to its edit page" do
    set_meeting_times
    sign_in identities(:head)

    get household_todays_meeting_path(household_id: households(:home))

    assert_redirected_to edit_household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_midweek))
  end

  test "no times: show offers Midweek and Weekend for this week" do
    sign_in identities(:spouse)

    assert_no_difference -> { MeetingNote.count } do
      get household_todays_meeting_path(household_id: households(:home))
    end

    assert_response :success
    assert_select "h1", "Today's meeting"
    assert_select "main h2", "Which meeting is it?"
    assert_select "main form[action='#{household_todays_meeting_path(household_id: households(:home))}']", count: 2
    { "midweek" => "Midweek meeting", "weekend" => "Weekend meeting" }.each do |kind, label|
      assert_select "main form:has(input[name='meeting_note[kind]'][value=#{kind}])" do
        assert_select "input[type=hidden][name='meeting_note[week_of]'][value='2026-11-16']"
        assert_select "button", label
      end
    end
  end

  test "a head sees Set your meeting times" do
    sign_in identities(:head)

    get household_todays_meeting_path(household_id: households(:home))

    assert_select "main a[href='#{household_settings_meetings_path(household_id: households(:home))}']", "Set your meeting times"
  end

  test "a child doesn't see Set your meeting times" do
    sign_in identities(:eli)

    get household_todays_meeting_path(household_id: households(:home))

    assert_response :success
    assert_select "main h2", "Which meeting is it?"
    assert_select "main a", text: "Set your meeting times", count: 0
  end

  test "an adult sees Set your meeting times too" do
    sign_in identities(:spouse)

    get household_todays_meeting_path(household_id: households(:home))

    assert_select "main a", "Set your meeting times"
  end

  test "create makes the note and redirects to its edit page" do
    set_meeting_times
    sign_in identities(:spouse)

    assert_difference -> { users(:spouse).meeting_notes.count }, 1 do
      post household_todays_meeting_path(household_id: households(:home)), params: { meeting_note: { kind: "midweek", week_of: "2026-11-16" } }
    end

    note = users(:spouse).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 16))
    assert_redirected_to edit_household_meeting_note_path(household_id: households(:home), id: note)
    assert_equal note.outline.parts.map(&:key), note.parts.map(&:key)
  end

  test "create without times makes the weekend note the picker offered" do
    sign_in identities(:eli)

    post household_todays_meeting_path(household_id: households(:home)), params: { meeting_note: { kind: "weekend", week_of: "2026-11-16" } }

    note = users(:eli).meeting_notes.find_by!(kind: "weekend", week_of: Date.new(2026, 11, 16))
    assert_redirected_to edit_household_meeting_note_path(household_id: households(:home), id: note)
  end

  test "posting twice makes one note" do
    set_meeting_times
    sign_in identities(:spouse)

    assert_difference -> { MeetingNote.count }, 1 do
      2.times { post household_todays_meeting_path(household_id: households(:home)), params: { meeting_note: { kind: "midweek", week_of: "2026-11-16" } } }
    end

    assert_redirected_to edit_household_meeting_note_path(household_id: households(:home), id: users(:spouse).meeting_notes.sole)
  end

  test "a kind or week_of that wasn't offered is 404" do
    set_meeting_times

    [ { kind: "weekend", week_of: "2026-11-16" }, # times set: only the midweek meeting is offered
      { kind: "midweek", week_of: "2026-11-23" },
      { kind: "midweek", week_of: "2026-11-19" }, # the right week, but not its Monday
      { kind: "midweek", week_of: "not a date" },
      { kind: "assembly", week_of: "2026-11-16" } ].each do |meeting_note|
      sign_in identities(:spouse) # a 404 doesn't keep the test's sign-in for the next request
      post household_todays_meeting_path(household_id: households(:home)), params: { meeting_note: }

      assert_response :not_found, "expected #{meeting_note} to be refused"
    end
    assert_empty users(:spouse).meeting_notes
  end

  test "without times, a week other than this one is 404" do
    sign_in identities(:spouse)

    post household_todays_meeting_path(household_id: households(:home)), params: { meeting_note: { kind: "midweek", week_of: "2026-11-09" } }

    assert_response :not_found
    assert_empty users(:spouse).meeting_notes
  end

  test "a household you're not in is 404" do
    sign_in identities(:spouse)

    get household_todays_meeting_path(household_id: households(:other))
    assert_response :not_found

    sign_in identities(:spouse)
    post household_todays_meeting_path(household_id: households(:other)), params: { meeting_note: { kind: "midweek", week_of: "2026-11-16" } }
    assert_response :not_found
    assert_empty users(:spouse).meeting_notes
  end

  test "a child with the helper and times set: create redirects to opening_song of the right meeting" do
    set_meeting_times
    turn_on_helper
    sign_in identities(:eli)

    post household_todays_meeting_path(household_id: households(:home)), params: { meeting_note: { kind: "midweek", week_of: "2026-11-16" } }

    note = users(:eli).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 16))
    assert_redirected_to household_meeting_note_step_path(household_id: households(:home), meeting_note_id: note, id: "opening_song")
  end

  test "a child with the helper and an existing note: show redirects to its first step" do
    set_meeting_times
    turn_on_helper
    note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    sign_in identities(:eli)

    get household_todays_meeting_path(household_id: households(:home))

    assert_redirected_to household_meeting_note_step_path(household_id: households(:home), meeting_note_id: note, id: "opening_song")
  end

  test "a child with the helper and times set, no note yet: show says hi and offers Start in the helper layout" do
    set_meeting_times
    turn_on_helper
    sign_in identities(:eli)

    assert_no_difference -> { MeetingNote.count } do
      get household_todays_meeting_path(household_id: households(:home))
    end

    assert_response :success
    assert_select "body[data-color-mode=dark]"
    assert_select "nav[aria-label='Main']", count: 0
    assert_select "header a[href='#{household_root_path(household_id: households(:home))}'][aria-label='Back to Aglowy']"
    assert_select "main h1", "Hi, Eli!"
    assert_select "main", text: /Midweek meeting · Thursday 7:00 PM/
    assert_select "main form[action='#{household_todays_meeting_path(household_id: households(:home))}']", count: 1 do
      assert_select "input[name='meeting_note[kind]'][value=midweek]"
      assert_select "button", "Start"
    end
  end

  test "a child with the helper and no times: show renders the picker in the helper layout" do
    turn_on_helper
    sign_in identities(:eli)

    get household_todays_meeting_path(household_id: households(:home))

    assert_response :success
    assert_select "title", "Today's meeting · The Head Family · Aglowy"
    assert_select "html[lang=en] body[data-color-mode=dark][data-light-theme=light][data-dark-theme=dark]"
    assert_select "nav[aria-label='Main']", count: 0
    assert_select "main h1", "Hi, Eli!"
    assert_select "main", text: /Which meeting is it\?/
    { "midweek" => [ "Midweek meeting", "8 parts" ], "weekend" => [ "Weekend meeting", "4 parts" ] }.each do |kind, (label, parts)|
      assert_select "main form:has(input[name='meeting_note[kind]'][value=#{kind}])" do
        assert_select "input[name='meeting_note[week_of]'][value='2026-11-16']"
        assert_select "button", label
      end
      assert_select "main", text: /#{parts}/
    end
    assert_select "main .meeting-helper__icon svg[aria-hidden=true]", count: 2
    assert_select "main a", text: "Set your meeting times", count: 0
  end

  test "a child with the helper off still gets the edit page" do
    set_meeting_times
    sign_in identities(:eli)

    get household_todays_meeting_path(household_id: households(:home))
    assert_select "body[data-color-mode=auto]"
    assert_select "main button", "Start my notes"

    post household_todays_meeting_path(household_id: households(:home)), params: { meeting_note: { kind: "midweek", week_of: "2026-11-16" } }
    assert_redirected_to edit_household_meeting_note_path(household_id: households(:home), id: users(:eli).meeting_notes.sole)

    get household_todays_meeting_path(household_id: households(:home))
    assert_redirected_to edit_household_meeting_note_path(household_id: households(:home), id: users(:eli).meeting_notes.sole)
  end

  test "a head with the helper on still gets their meeting note" do
    set_meeting_times
    turn_on_helper
    sign_in identities(:head)

    get household_todays_meeting_path(household_id: households(:home))

    assert_redirected_to edit_household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_midweek))
  end

  private
    def turn_on_helper
      households(:home).enable_meeting_helper(by: users(:head))
    end

    # Midweek on Thursday at 7:00 PM, weekend on Sunday at 10:00 AM.
    def set_meeting_times
      households(:home).change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    end
end
