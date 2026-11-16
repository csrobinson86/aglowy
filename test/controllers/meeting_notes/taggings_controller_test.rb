require "test_helper"

class MeetingNotes::TaggingsControllerTest < ActionDispatch::IntegrationTest
  setup { @note = meeting_notes(:head_weekend) }

  test "adds a new tag to a note, and the editor is replaced" do
    sign_in identities(:head)

    assert_difference -> { users(:head).tags.count } do
      post taggings_path(@note), params: { name: "Talk Prep" }, as: :turbo_stream
    end

    assert_response :success
    assert_equal %w[ talk-prep ], @note.tags.pluck(:name)
    assert_select "turbo-stream[action=replace][target='tag_editor_meeting_note_#{@note.id}']"
    assert_select "turbo-stream template a.Label", text: "#talk-prep"
    assert_select "turbo-stream template [data-tag-editor-focus-value=true]"
  end

  test "adds an existing tag typed differently, without making another" do
    sign_in identities(:head)

    assert_no_difference -> { Tag.count } do
      post taggings_path(@note), params: { name: "#Ministry" }, as: :turbo_stream
    end

    assert_response :success
    assert_equal [ tags(:head_ministry) ], @note.tags.to_a
  end

  test "removes one" do
    @note.tag_with("ministry", by: users(:head))
    @note.tag_with("prayer", by: users(:head))
    sign_in identities(:head)

    assert_difference -> { @note.taggings.count }, -1 do
      delete tagging_path(@note, tags(:head_ministry)), as: :turbo_stream
    end

    assert_response :success
    assert_equal %w[ prayer ], @note.tags.pluck(:name)
    assert_select "turbo-stream template a.Label", text: "#prayer"
    assert_select "turbo-stream template a.Label", text: "#ministry", count: 0
    assert tags(:head_ministry).reload, "the tag stays for the person's other things"
    assert_select "turbo-stream template [data-tag-editor-focus-value=true]"
  end

  test "another person's note: 404" do
    sign_in identities(:spouse)

    assert_no_difference -> { Tagging.count } do
      post taggings_path(@note), params: { name: "ministry" }, as: :turbo_stream
    end
    assert_response :not_found

    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:spouse) # a 404 doesn't keep the session

    assert_no_difference -> { Tagging.count } do
      delete tagging_path(meeting_notes(:head_midweek), tags(:head_ministry)), as: :turbo_stream
    end
    assert_response :not_found
  end

  test "another person's tag: 404" do
    sign_in identities(:head)

    assert_no_difference -> { Tagging.count } do
      delete tagging_path(meeting_notes(:head_midweek), tags(:spouse_ministry)), as: :turbo_stream
    end
    assert_response :not_found
  end

  test "an 11th tag: an error in the editor" do
    10.times { @note.tag_with("tag-#{it}", by: users(:head)) }
    sign_in identities(:head)

    assert_no_difference -> { Tagging.count } do
      post taggings_path(@note), params: { name: "one-more" }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target='tag_editor_meeting_note_#{@note.id}']"
    assert_includes response.body, "This already has 10 tags, the most it can have"
    assert_not users(:head).tags.exists?(name: "one-more")
  end

  test "a name that normalizes to nothing: an error in the editor" do
    sign_in identities(:head)

    assert_no_difference -> { Tag.count } do
      post taggings_path(@note), params: { name: "###" }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Name needs at least one letter or number"
  end

  test "a blank or whitespace-only name: an error in the editor" do
    sign_in identities(:head)

    [ "", "   " ].each do |name|
      assert_no_difference -> { Tag.count } do
        post taggings_path(@note), params: { name: name }, as: :turbo_stream
      end

      assert_response :unprocessable_content
      assert_select "turbo-stream[action=replace][target='tag_editor_meeting_note_#{@note.id}']"
      assert_includes response.body, "Name needs at least one letter or number"
    end
  end

  private
    def taggings_path(note, household = households(:home))
      household_meeting_note_taggings_path(household_id: household, meeting_note_id: note)
    end

    def tagging_path(note, tag, household = households(:home))
      household_meeting_note_tagging_path(household_id: household, meeting_note_id: note, id: tag)
    end
end
