require "application_system_test_case"

class ListeningGameParentTest < ApplicationSystemTestCase
  setup do
    # Wednesday of the week of 9 November, the home household's game (listening_games.yml): a first talk round with
    # Jeremiah to find, and a second added here.
    travel_to Time.utc(2026, 11, 11, 12)
    households(:home).enable_meeting_helper(by: users(:head))
    @second = listening_round("talk", 2, answer: "Tears", others: [ "A rainbow", "A lion", "A boat" ], kind: "feeling")
    listening_round("bible_reading", 1, answer: "Lamentations", others: %w[ Genesis Psalms Jonah ], kind: "book")
  end

  test "the day before the midweek meeting, a head goes from Home to this week's game" do
    households(:home).change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    assert_no_selector ".todays-meeting-card"
    assert_selector "x-banner", text: "Check this week's listening game before the midweek meeting."
    assert_accessible
    capture_screens("listening-game-home")

    within("x-banner") { click_on "Check this week's listening game" }

    assert_selector "h1", text: "This week's listening game"
  end

  test "a head changes round 2 and the child's tablet shows the new card; a label with <script> shows as text" do
    sign_in identities(:head)
    visit household_settings_children_url(household_id: households(:home))
    click_on "Check this week's listening game"

    assert_selector "h1", text: "This week's listening game"
    assert_link "Life and Ministry Meeting Workbook, November 9-15"
    assert_selector "#listening-game-talk", text: /Tears\s+A rainbow · A lion · A boat/
    assert_accessible
    capture_screens("listening-game-check")

    within("#listening_game_round_#{@second.id}") { click_on "Change" }

    assert_selector "dialog[open] h1", text: "Treasures · round 2 of 2"
    assert_field "Heard in the talk", with: "Tears"
    wait_for_dialog
    assert_accessible
    capture_screens("listening-game-change")

    fill_in "Heard in the talk", with: "<script>alert(1)</script>"
    fill_in "Other card 2", with: "A tent"
    click_on "Save"

    assert_no_selector "dialog[open]"
    assert_text "Round saved."
    within("#listening_game_round_#{@second.id}") do
      assert_text "<script>alert(1)</script>"
      assert_text "A rainbow · A tent · A boat"
    end
    assert_no_selector "main script", visible: :all
    assert_accessible

    sign_out :identity
    note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    sign_in identities(:eli)
    visit household_meeting_note_step_round_url(household_id: households(:home), meeting_note_id: note, step_id: "talk", id: 2)

    assert_selector "button[name=card]", text: "<script>alert(1)</script>"
    assert_selector "button[name=card]", text: "A tent"
    assert_no_selector "button[name=card]", text: "Tears"
    assert_no_selector "main script", visible: :all
  end
end
