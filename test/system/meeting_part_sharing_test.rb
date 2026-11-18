require "application_system_test_case"

# Sharing a part with the household, and another member reading it (docs/design/meeting-parts.md, Sharing; frame
# part-shared.png).
class MeetingPartSharingTest < ApplicationSystemTestCase
  setup do
    @part = meeting_parts(:head_conversation)
    @part.update!(preparation: "<p>Good morning. Do you think problems like these will ever be solved?</p>", counsel: "Slow down at the start.")
  end

  test "share, see the Label, read it as another member, stop sharing, it's gone for them" do
    sign_in identities(:head)
    visit household_meeting_part_url(household_id: households(:home), id: @part)
    assert_selector "h1 .Label", text: "Private"

    click_on "Share with household"
    wait_for_dialog
    within("dialog[open]") do
      assert_selector "h1", text: "Share with The Head Family?"
      assert_text "Everyone in The Head Family will be able to read the part and your preparation, not your counsel."
      assert_text "The Grandparent Family won't see it."
    end
    assert_accessible
    capture_screens("part-share-dialog")

    within("dialog[open]") { click_on "Share part" }
    assert_text "Shared with The Head Family."
    assert_no_selector "dialog[open]"
    assert_selector "h1 .Label", text: "Shared with The Head Family"
    assert_button "Stop sharing"
    visit household_meeting_parts_url(household_id: households(:home))
    within("section[aria-labelledby=coming-up]") { assert_selector ".Label", text: "Shared" }

    sign_out :identity
    sign_in identities(:spouse)
    visit household_meeting_parts_url(household_id: households(:home))
    click_on "Shared in The Head Family"
    within("section[aria-labelledby=coming-up]") { assert_text "Hannah Head" }
    assert_accessible
    capture_screens("shared-meeting-parts")
    click_on "Starting a Conversation"

    assert_selector "h1", text: "Starting a Conversation"
    assert_text "shared by Hannah Head"
    assert_text "Good morning. Do you think problems like these will ever be solved?"
    assert_no_text "Slow down at the start."
    assert_no_selector "main lexxy-editor, main textarea"
    %w[ Share Stop Edit Delete Save ].each { assert_no_button it, exact: false }
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Meeting parts"
    assert_accessible
    capture_screens("part-shared")

    sign_out :identity
    sign_in identities(:head)
    visit household_meeting_part_url(household_id: households(:home), id: @part)
    click_on "Stop sharing"
    assert_text "Stopped sharing with The Head Family."
    assert_selector "h1 .Label", text: "Private"
    assert_selector "button", text: "Share with household"

    sign_out :identity
    sign_in identities(:spouse)
    visit household_shared_meeting_parts_url(household_id: households(:home))
    assert_text "Nothing shared yet"
    assert_no_text "Starting a Conversation"
  end
end
