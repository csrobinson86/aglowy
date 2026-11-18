require "application_system_test_case"

class MeetingPartsTest < ApplicationSystemTestCase
  # Moves the caret to the end of the editor's text: Cmd+Down on a Mac, Ctrl+End on Linux CI.
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]
  EDITOR = "lexxy-editor[name='meeting_part[preparation]']"

  setup do
    households(:home).change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    sign_in identities(:head)
  end

  test "add a part, write preparation with a reference, save, see the scripture link; add counsel; edit; delete" do
    visit household_meeting_parts_url(household_id: households(:home))

    assert_selector "h1", text: "Meeting parts"
    assert_selector "aside nav [aria-current=page]", text: "Meeting parts"
    assert_selector "section[aria-labelledby=coming-up] li", count: 1
    assert_accessible
    capture_screens("meeting-parts")

    click_on "Add a part"
    wait_for_dialog
    within("dialog[open]") do
      assert_text "Add a part"
      assert_text "Your next midweek meeting."
      assert_equal households(:home).next_midweek_meeting_on.iso8601, find_field("Meeting date").value
      select "Explaining Your Beliefs (talk)", from: "Part"
      fill_in "Minutes", with: "5"
      fill_in "What it's about", with: "Why we use God's name"
      fill_in "Study point (optional)", with: "th study 3"
    end
    assert_accessible
    capture_screens("part-new")
    within("dialog[open]") { click_on "Add part" }

    assert_text "Part added."
    assert_no_selector "dialog[open]"
    assert_selector "section[aria-labelledby=coming-up] li", count: 2
    click_on "Explaining Your Beliefs", match: :first

    assert_selector "h1", text: "Explaining Your Beliefs"
    assert_text "Why we use God's name"
    editable = find("#{EDITOR} [contenteditable='true']")
    editable.click
    editable.send_keys(END_OF_TEXT, "Start with Psalm 83:18 and explain the name.")
    click_on "Save"

    assert_text "Part saved."
    assert_selector "#{EDITOR} .scripture-link", text: "Psalm 83:18"

    fill_in "Counsel, and what to work on next", with: "Clear reasons. Next: a warmer close."
    click_on "Save"
    assert_text "Part saved."
    assert_field "Counsel, and what to work on next", with: "Clear reasons. Next: a warmer close."
    assert_selector "#{EDITOR} .scripture-link", text: "Psalm 83:18"
    find("h1").hover # off Save, whose hover green is Primer's and too light for white text
    wait_for_transitions
    assert_accessible
    capture_screens("part")

    click_on "Edit"
    wait_for_dialog
    within("dialog[open]") do
      assert_text "Edit part"
      fill_in "Assistant (optional)", with: "Ana Ortiz"
      click_on "Save part"
    end
    assert_text "Part saved."
    assert_no_selector "dialog[open]"
    assert_text "Ana Ortiz"

    click_on "Delete"
    wait_for_dialog
    within("dialog[open]") { click_on "Delete part" }

    assert_text "Part deleted."
    assert_selector "h1", text: "Meeting parts"
    assert_selector "section[aria-labelledby=coming-up] li", count: 1
    assert_no_text "Why we use God's name"
  end

  test "a child opens their own part to prepare it" do
    sign_in identities(:eli)
    visit household_meeting_part_url(household_id: households(:home), id: meeting_parts(:eli_conversation))

    assert_selector "h1", text: "Starting a Conversation"
    assert_selector "aside nav [aria-current=page]", text: "Meeting parts"
    assert_accessible
    capture_screens("part-child")
  end

  test "with no parts, the list offers Add a part" do
    sign_in identities(:grandparent)
    visit household_meeting_parts_url(household_id: households(:parents))

    assert_selector ".blankslate", text: "No parts yet"
    assert_accessible
    capture_screens("meeting-parts-empty")
  end
end
