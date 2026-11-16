require "test_helper"

class TagEditorComponentTest < ViewComponent::TestCase
  setup { @note = meeting_notes(:head_weekend) }

  test "no tags: only the Add a tag input" do
    render_inline(TagEditorComponent.new(taggable: @note, user: users(:head), household: households(:home)))

    assert_selector "#tag_editor_meeting_note_#{@note.id}"
    assert_no_selector ".Label"
    assert_no_selector "button[aria-label^='Remove tag']"
    assert_selector "form[action='#{taggings_path}'][method=post] auto-complete input[name=name]"
    assert_selector "label", text: "Add a tag"
  end

  test "two tags: each a Label linking to the list filtered by it, with its remove button" do
    @note.tag_with("ministry", by: users(:head))
    @note.tag_with("Talk Prep", by: users(:head))

    render_inline(TagEditorComponent.new(taggable: @note, user: users(:head), household: households(:home)))

    assert_selector ".Label", count: 2
    assert_selector "a.Label[href='/#{households(:home).id}/meeting_notes?tag=ministry']", text: "#ministry"
    assert_selector "a.Label[href='/#{households(:home).id}/meeting_notes?tag=talk-prep']", text: "#talk-prep"
    talk_prep = users(:head).tags.find_by!(name: "talk-prep")
    assert_selector "form[action='#{taggings_path}/#{talk_prep.id}'] button[type=submit][aria-label='Remove tag talk-prep']"
    assert_selector "button[aria-label='Remove tag ministry']"
  end

  test "suggestions list only the viewer's own tags, with their counts, and not ones already on it" do
    users(:head).tags.create!(name: "prayer")
    meeting_notes(:head_midweek).tag_with("prophecy", by: users(:head))
    @note.tag_with("prophecy", by: users(:head))
    users(:spouse).tags.create!(name: "spouses-secret")

    render_inline(TagEditorComponent.new(taggable: @note, user: users(:head), household: households(:home)))

    suggestions = rendered_content[%r{<template data-tag-editor-target="suggestions">.*?</template>}m]
    assert_includes suggestions, %(data-autocomplete-value="ministry")
    assert_includes suggestions, %(data-autocomplete-value="prayer")
    assert_not_includes suggestions, %(data-autocomplete-value="prophecy")
    assert_not_includes suggestions, "spouses-secret"
    assert_match(/#ministry.*title="1"/m, suggestions)
    assert_match(/#prayer.*title="0"/m, suggestions)
  end

  test "an error shows with the input" do
    render_inline(TagEditorComponent.new(taggable: @note, user: users(:head), household: households(:home), error: "This already has 10 tags, the most it can have"))

    assert_text "This already has 10 tags, the most it can have"
    assert_selector "input[name=name][aria-invalid=true]"
  end

  test "renders nothing for anyone but the owner, nor on a family goal" do
    @note.tag_with("ministry", by: users(:head))

    render_inline(TagEditorComponent.new(taggable: @note, user: users(:spouse), household: households(:home)))
    assert_no_selector "*"

    render_inline(TagEditorComponent.new(taggable: goals(:gospels), user: users(:spouse), household: households(:home)))
    assert_no_selector "*"
  end

  test "on a personal goal, Labels filter My goals and the forms post to the goal's taggings" do
    goal = goals(:spouse_bible_reading)
    goal.tag_with("ministry", by: users(:spouse))

    render_inline(TagEditorComponent.new(taggable: goal, user: users(:spouse), household: households(:home)))

    assert_selector "a.Label[href='/#{households(:home).id}/my_goals?tag=ministry']", text: "#ministry"
    assert_selector "form[action='/#{households(:home).id}/goals/#{goal.id}/taggings']"
  end

  private

  def taggings_path
    "/#{households(:home).id}/meeting_notes/#{@note.id}/taggings"
  end
end
