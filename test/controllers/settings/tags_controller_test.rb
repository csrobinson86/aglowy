require "test_helper"

# Settings → Tags and collections (docs/design/settings.md, Tags and collections).
class Settings::TagsControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "lists only my own tags and collections" do
    sign_in identities(:head)
    meeting_notes(:head_weekend).tag_with("ministry", by: users(:head))
    users(:head).tags.create!(name: "prayer")
    users(:spouse).tags.create!(name: "comfort")
    personal_notes(:head_return_visit).update!(collection: collections(:head_bible_questions))

    get household_settings_tags_path(household_id: @home)

    assert_response :success
    assert_select "main h2", "Tags and collections"
    assert_select "main", text: /Rename or delete your tags and collections\. Only you see them\./
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Tags and collections"
    assert_select "aside nav a[aria-current=page]", "Settings"
    assert_select "#my-tags .Box-row", count: 2
    assert_select "#my-tags .Box-row", text: /#ministry\s+2 items/
    assert_select "#my-tags .Box-row", text: /#prayer\s+0 items/
    assert_select "#my-tags a.Label[href=?]", household_tag_path(household_id: @home, name: "ministry")
    assert_select "#my-tags", text: /#comfort/, count: 0
    assert_equal [ "Bible questions", "Preparing a talk", "Quick references" ], css_select("#collections .Box-row .collection-row__name").map { it.text.strip }
    assert_select "#collections .Box-row", text: /Bible questions\s+· 1 note, 1 study\s+Used in Notes and Personal study/
    assert_select "#collections .Box-row", text: /Preparing a talk\s+· 1 study\s+Used in Personal study only/
    assert_select "#collections .Box-row", text: /Quick references\s+· 1 note\s+Used in Notes only/
    assert_select "#collections", text: /Ministry/, count: 0
    assert_select "#collections", text: /Create collections from Personal study or Notes\./
    assert_select "form[action=?]", household_collection_path(household_id: @home, id: collections(:head_talks))
  end

  test "no tags and no collections yet" do
    sign_in identities(:eli)

    get household_settings_tags_path(household_id: @home)

    assert_response :success
    assert_select "#my-tags", text: /No tags yet/
    assert_select "#my-tags", text: /Add a tag from a meeting note, a goal, a study or a note\./
    assert_select "#collections", text: /No collections yet\./
  end

  test "a non-member: 404" do
    sign_in identities(:head)

    get household_settings_tags_path(household_id: households(:other))

    assert_response :not_found
  end
end
