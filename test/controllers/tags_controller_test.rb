require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @ministry = tags(:head_ministry)
    sign_in identities(:head)
  end

  test "index lists each of my tags with how many things carry it" do
    meeting_notes(:head_weekend).tag_with("ministry", by: users(:head))
    users(:head).tags.create!(name: "prayer")

    get household_tags_path(household_id: @home)

    assert_response :success
    assert_select "main .Box-row", count: 2
    assert_select "main .Box-row", text: /#ministry\s+2 items/
    assert_select "main .Box-row", text: /#prayer\s+0 items/
    assert_select "main a.Label[href=?]", household_tag_path(household_id: @home, name: "ministry")
  end

  test "show groups my meeting notes and goals tagged with it, newest first" do
    meeting_notes(:head_weekend).tag_with("ministry", by: users(:head))
    goal = users(:head).goals.create!(title: "Start a Bible study", target_on: Date.new(2027, 1, 31), set_by: users(:head))
    goal.tag_with("ministry", by: users(:head))

    get household_tag_path(household_id: @home, name: "ministry")

    assert_response :success
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

  test "an unknown name, or another person's tag name: 404" do
    get household_tag_path(household_id: @home, name: "prayer")
    assert_response :not_found

    sign_in identities(:spouse) # a 404 doesn't keep the session
    tags(:spouse_ministry).destroy
    get household_tag_path(household_id: @home, name: "ministry")
    assert_response :not_found
  end

  test "rename to a free name" do
    patch household_tag_path(household_id: @home, name: "ministry"), params: { tag: { name: "Field Service" } }

    assert_redirected_to household_tags_path(household_id: @home)
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

  test "delete removes the tag and its taggings" do
    assert_difference -> { Tagging.count } => -1, -> { Tag.count } => -1 do
      delete household_tag_path(household_id: @home, name: "ministry")
    end

    assert_redirected_to household_tags_path(household_id: @home)
    assert_empty meeting_notes(:head_midweek).tags.reload
  end

  test "not a member of the household: 404" do
    get household_tags_path(household_id: households(:other))

    assert_response :not_found
  end
end
