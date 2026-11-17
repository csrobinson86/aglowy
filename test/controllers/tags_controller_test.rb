require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @ministry = tags(:head_ministry)
    sign_in identities(:head)
  end

  test "show groups my meeting notes and goals tagged with it, newest first" do
    meeting_notes(:head_weekend).tag_with("ministry", by: users(:head))
    goal = users(:head).goals.create!(title: "Start a Bible study", target_on: Date.new(2027, 1, 31), set_by: users(:head))
    goal.tag_with("ministry", by: users(:head))

    get household_tag_path(household_id: @home, name: "ministry")

    assert_response :success
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", household_settings_tags_path(household_id: @home), text: "Tags and collections"
    assert_select "h1", text: "#ministry"
    assert_select "h2", text: /Meeting notes\s+2/
    assert_select "h2", text: /My goals\s+1/
    assert_select "h2", text: /Personal studies/, count: 0
    assert_select "section[aria-labelledby=meeting-notes] .Box-row a" do |links|
      assert_equal [ "Weekend meeting", "Life and Ministry" ], links.map { it.text.strip }
    end
    assert_select "section[aria-labelledby=my-goals] .Box-row a[href=?]", household_goal_path(household_id: @home, id: goal), text: "Start a Bible study"
  end

  test "show groups my personal studies tagged with it" do
    study = personal_studies(:head_daniel)
    study.tag_with("ministry", by: users(:head))
    personal_studies(:spouse_ransom).tag_with("ministry", by: users(:spouse))

    get household_tag_path(household_id: @home, name: "ministry")

    assert_select "h2", text: /Personal studies\s+1/
    assert_select "section[aria-labelledby=personal-studies] .Box-row a[href=?]", household_personal_study_path(household_id: @home, id: study), text: study.title
  end

  test "the tag page lists a bookmark under Bookmarks" do
    bookmark = bookmarks(:head_suffering_article)
    bookmark.tag_with("ministry", by: users(:head))
    bookmarks(:spouse_ransom_article).tag_with("ministry", by: users(:spouse))

    get household_tag_path(household_id: @home, name: "ministry")

    assert_select "h2", text: /Bookmarks\s+1/
    assert_select "section[aria-labelledby=bookmarks] .Box-row a[href=?][target=_blank][rel~=noopener]", bookmark.url, text: "Why Does God Allow Suffering?"
    assert_select "section[aria-labelledby=bookmarks]", text: /The Ransom/, count: 0
  end

  test "show lists a tagged note under Notes" do
    note = personal_notes(:head_daniel)
    note.tag_with("ministry", by: users(:head))
    personal_notes(:spouse_grieving).tag_with("ministry", by: users(:spouse))

    get household_tag_path(household_id: @home, name: "ministry")

    assert_select "h2", text: /Notes\s+1/
    assert_select "section[aria-labelledby=personal-notes] .Box-row a[href=?]", household_personal_note_path(household_id: @home, id: note), text: note.title
  end

  test "an unknown name, or another person's tag name: 404" do
    get household_tag_path(household_id: @home, name: "prayer")
    assert_response :not_found

    sign_in identities(:spouse) # a 404 doesn't keep the session
    tags(:spouse_ministry).destroy
    get household_tag_path(household_id: @home, name: "ministry")
    assert_response :not_found
  end

  test "rename to a free name returns to Settings" do
    patch household_tag_path(household_id: @home, name: "ministry"), params: { tag: { name: "Field Service" } }

    assert_redirected_to household_settings_tags_path(household_id: @home)
    assert_equal "field-service", @ministry.reload.name
    assert_equal [ @ministry ], meeting_notes(:head_midweek).tags.to_a
  end

  test "rename to a taken name shows the error" do
    users(:head).tags.create!(name: "prayer")

    patch household_tag_path(household_id: @home, name: "ministry"), params: { tag: { name: "#Prayer" } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target='rename_tag_#{@ministry.id}'] template", text: /You already have #prayer\./
    assert_equal "ministry", @ministry.reload.name
  end

  test "delete removes the tag and its taggings, and returns to Settings" do
    assert_difference -> { Tagging.count } => -1, -> { Tag.count } => -1 do
      delete household_tag_path(household_id: @home, name: "ministry")
    end

    assert_redirected_to household_settings_tags_path(household_id: @home)
    assert_empty meeting_notes(:head_midweek).tags.reload
  end

  test "My tags moved to Settings: GET /:household_id/tags is gone" do
    get "/#{@home.id}/tags"

    assert_response :not_found
    assert_not respond_to?(:household_tags_path)
  end

  test "not a member of the household: 404" do
    get household_tag_path(household_id: households(:other), name: "ministry")

    assert_response :not_found
  end
end
