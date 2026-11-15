require "application_system_test_case"

# A child's Today's meeting note, shared from the end screen and read by a parent (docs/design/meeting-helper.md,
# Pages: A helper note, read; frame phone-parent.png).
class HelperNoteTest < ApplicationSystemTestCase
  test "a child shares from the summary, and the head opens it and sees Talk about it with Eli" do
    households(:home).enable_meeting_helper(by: users(:head))
    note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    %w[ opening_song talk spiritual_gems bible_reading living ].each { note.mark(it) }
    note.draw("field_ministry", Rack::Test::UploadedFile.new(file_fixture("helper-drawing.png"), "image/png"))
    sign_in identities(:eli)
    visit household_meeting_note_summary_url(household_id: households(:home), meeting_note_id: note)
    click_on "Show my family"
    assert_selector "[role=status]", text: "Your family can see it now"

    sign_out :identity
    sign_in identities(:head)
    visit household_shared_meeting_notes_url(household_id: households(:home))
    within("main .Box") { click_on "Life and Ministry" }

    assert_selector "h1 .Label", text: "Shared by Eli Child · from Today's meeting"
    assert_selector "h3", text: "Talk about it with Eli"
    assert_selector "li", text: "Tell me about your drawing of field ministry."
    assert_selector ".Box-row", text: "Treasures From God's Word\n✓ Heard it"
    assert_selector ".Box-row", text: "Congregation Bible Study\nNot marked"
    assert_selector "img[alt=\"Eli's drawing for Apply Yourself to the Field Ministry\"]" do |drawing|
      drawing.evaluate_script("this.complete && this.naturalWidth > 0")
    end
    assert_no_button "Stop sharing"
    assert_accessible
    capture_screens("helper-note-parent")
  end
end
