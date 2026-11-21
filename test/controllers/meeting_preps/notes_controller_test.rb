require "test_helper"

class MeetingPreps::NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Tuesday of the week of 9 November, whose talk and Bible Reading cards are in prep_week_cards.yml.
    travel_to Time.utc(2026, 11, 10, 16)
    @home = households(:home)
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @home.enable_meeting_helper(by: users(:head))
    @home.enable_meeting_prep(by: users(:head))
    week = prep_weeks(:home_nov_9)
    week.cards.create!(meeting: "midweek", step: "congregation_bible_study", about: "Jesus loved little children.", quality: "loving",
                       quality_line: "Jesus showed us how Jehovah loves.", i_can: "Smile at the people at the meeting.")
    week.cards.create!(meeting: "weekend", step: "watchtower_study", about: "Jehovah gives us friends.", quality: "generous",
                       quality_line: "He gives us a congregation.", i_can: "Say hello to someone new.")
  end

  test "Get my comment ready starts her note once, and opens her answer on the Bible Study with from=prep" do
    sign_in identities(:eli)

    assert_difference -> { users(:eli).meeting_notes.count }, 1 do
      post note_path("midweek"), params: { to: "answer" }
      post note_path("midweek"), params: { to: "answer" }
    end

    note = users(:eli).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 9))
    assert_redirected_to edit_household_meeting_note_step_answer_path(household_id: @home, meeting_note_id: note, step_id: "congregation_bible_study", from: "prep")
  end

  test "on the weekend, her answer is on the Watchtower Study" do
    sign_in identities(:eli)

    post note_path("weekend"), params: { to: "answer" }

    note = users(:eli).meeting_notes.find_by!(kind: "weekend", week_of: Date.new(2026, 11, 9))
    assert_redirected_to edit_household_meeting_note_step_answer_path(household_id: @home, meeting_note_id: note, step_id: "watchtower_study", from: "prep")
  end

  test "Draw it! starts her note once, and opens the Bible Reading drawing with from=prep" do
    sign_in identities(:eli)

    assert_difference -> { users(:eli).meeting_notes.count }, 1 do
      post note_path("midweek"), params: { to: "drawing" }
      post note_path("midweek"), params: { to: "drawing" }
    end

    note = users(:eli).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 9))
    assert_redirected_to edit_household_meeting_note_step_drawing_path(household_id: @home, meeting_note_id: note, step_id: "bible_reading", from: "prep")
  end

  test "an unknown to is a 404, and starts no note" do
    sign_in identities(:eli)

    assert_no_difference -> { MeetingNote.count } do
      post note_path("midweek"), params: { to: "https://example.com" }
    end
    assert_response :not_found
  end

  test "no to is a 404" do
    sign_in identities(:eli)

    post note_path("midweek")

    assert_response :not_found
  end

  test "a drawing on the weekend is a 404: it has no Bible Reading card" do
    sign_in identities(:eli)

    assert_no_difference -> { MeetingNote.count } do
      post note_path("weekend"), params: { to: "drawing" }
    end
    assert_response :not_found
  end

  test "a meeting that isn't midweek or weekend is a 404" do
    sign_in identities(:eli)

    post note_path("monday"), params: { to: "answer" }

    assert_response :not_found
  end

  test "a step with no card this week is a 404" do
    prep_weeks(:home_nov_9).cards.where(step: "congregation_bible_study").delete_all
    sign_in identities(:eli)

    assert_no_difference -> { MeetingNote.count } do
      post note_path("midweek"), params: { to: "answer" }
    end
    assert_response :not_found
  end

  test "a head is a 404" do
    sign_in identities(:head)

    assert_no_difference -> { MeetingNote.count } do
      post note_path("midweek"), params: { to: "answer" }
    end
    assert_response :not_found
  end

  test "an adult is a 404" do
    sign_in identities(:spouse)

    post note_path("midweek"), params: { to: "drawing" }

    assert_response :not_found
  end

  test "a child with Get ready off is a 404" do
    @home.disable_meeting_prep
    sign_in identities(:eli)

    assert_no_difference -> { MeetingNote.count } do
      post note_path("midweek"), params: { to: "answer" }
    end
    assert_response :not_found
  end

  private
    def note_path(meeting)
      household_meeting_prep_note_path(household_id: @home, meeting_prep_meeting: meeting)
    end
end
