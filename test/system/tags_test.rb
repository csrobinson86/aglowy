require "application_system_test_case"

class TagsTest < ApplicationSystemTestCase
  # Wednesday of the week the fixture notes are for (16–22 November 2026).
  setup { travel_to Time.utc(2026, 11, 18, 12) }

  test "add #Ministry to a meeting note with the keyboard, filter the list by it, remove it" do
    note = meeting_notes(:head_weekend)
    users(:head).tags.create!(name: "prayer")
    sign_in identities(:head)
    visit household_meeting_note_url(household_id: households(:home), id: note)

    input = find_field("Add a tag")
    input.send_keys("Min")
    within("[role=listbox]") do
      assert_selector "[role=option]", text: "#ministry"
      assert_selector "[role=option]", text: 'Create "#min"'
      assert_no_selector "[role=option]", text: "#prayer"
    end
    capture_screens("tag-suggestions", viewports: ScreenshotHelper::VIEWPORTS.slice(:desktop))
    input.send_keys(:escape)
    assert_no_selector "[role=listbox]"

    input.send_keys("istry", :enter)

    within("#tag_editor_meeting_note_#{note.id}") { assert_selector "a.Label", text: "#ministry" }
    assert_equal "Add a tag", page.evaluate_script("document.activeElement.labels[0].textContent").strip
    assert_equal [ tags(:head_ministry) ], note.tags.to_a
    assert_accessible
    capture_screens("tag-editor")

    visit household_meeting_notes_url(household_id: households(:home), tag: "ministry")

    assert_selector "a[aria-label='Remove filter #ministry']"
    assert_selector "main .Box-row", count: 2
    assert_accessible
    capture_screens("tag-filter")

    visit household_meeting_note_url(household_id: households(:home), id: note)
    find("button[aria-label='Remove tag ministry']").click

    within("#tag_editor_meeting_note_#{note.id}") { assert_no_selector "a.Label" }
    assert_equal "Add a tag", page.evaluate_script("document.activeElement.labels[0].textContent").strip
    assert_empty note.tags.reload
  end

  test "open #ministry from a note's Label and see the note and a goal" do
    goal = users(:head).goals.create!(title: "Start a Bible study by the end of the year", target_on: Date.new(2026, 12, 31), set_by: users(:head))
    goal.tag_with("ministry", by: users(:head))
    sign_in identities(:head)
    visit household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))

    within("#tag_editor_meeting_note_#{meeting_notes(:head_midweek).id}") { click_on "#ministry" }

    assert_current_path household_tag_path(household_id: households(:home), name: "ministry")
    assert_selector "h1", text: "#ministry"
    within("section", text: "Meeting notes") { assert_link "Life and Ministry" }
    within("section", text: "My goals") { assert_link goal.title }
    assert_no_selector "aside nav [aria-current=page]"
    assert_accessible
    capture_screens("tag-page")

    click_on goal.title
    assert_current_path household_goal_path(household_id: households(:home), id: goal)
  end

  test "create a new tag from the suggestions" do
    note = meeting_notes(:head_weekend)
    sign_in identities(:head)
    visit household_meeting_note_url(household_id: households(:home), id: note)

    find_field("Add a tag").send_keys("Talk Prep")
    find("[role=option]", text: 'Create "#talk-prep"').click

    within("#tag_editor_meeting_note_#{note.id}") { assert_selector "a.Label", text: "#talk-prep" }
  end

  test "a nonbreaking space is dropped, as the server drops it, not made a hyphen" do
    note = meeting_notes(:head_weekend)
    sign_in identities(:head)
    visit household_meeting_note_url(household_id: households(:home), id: note)

    find_field("Add a tag").send_keys("talk\u00A0prep")

    assert_selector "[role=option]", text: 'Create "#talkprep"'
  end

  test "My goals filtered by a tag, and by one nothing carries" do
    goals(:spouse_bible_reading).tag_with("ministry", by: users(:spouse))
    sign_in identities(:spouse)

    visit household_my_goals_url(household_id: households(:home), tag: "ministry")

    assert_selector "main .Box-row a.Label", text: "#ministry"
    assert_selector "a[aria-label='Remove filter #ministry']"
    assert_accessible
    capture_screens("tag-filter-goals")

    visit household_my_goals_url(household_id: households(:home), tag: "prayer")

    assert_selector ".blankslate h2", text: "No goals tagged #prayer"
    assert_accessible
  end

  test "another household member reading the shared note sees no tags" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:spouse)

    visit household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))

    assert_text "Hannah Head shared this note with The Head Family."
    assert_no_field "Add a tag"
    assert_no_text "#ministry"
    assert_accessible
  end
end
