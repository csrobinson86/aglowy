require "test_helper"

class Goals::TaggingsControllerTest < ActionDispatch::IntegrationTest
  setup { @goal = goals(:spouse_bible_reading) }

  test "the owner adds an existing tag to a personal goal, then removes it" do
    sign_in identities(:spouse)

    assert_no_difference -> { Tag.count } do
      post taggings_path(@goal), params: { name: "Ministry" }, as: :turbo_stream
    end
    assert_response :success
    assert_equal [ tags(:spouse_ministry) ], @goal.tags.to_a
    assert_select "turbo-stream[action=replace][target='tag_editor_goal_#{@goal.id}'] template a.Label", text: "#ministry"

    delete tagging_path(@goal, tags(:spouse_ministry)), as: :turbo_stream

    assert_response :success
    assert_empty @goal.tags.reload
  end

  test "a family goal: 404" do
    sign_in identities(:spouse)

    assert_no_difference -> { Tagging.count } do
      post taggings_path(goals(:gospels)), params: { name: "ministry" }, as: :turbo_stream
    end
    assert_response :not_found

    sign_in identities(:spouse) # a 404 doesn't keep the session
    delete tagging_path(goals(:gospels), tags(:spouse_ministry)), as: :turbo_stream
    assert_response :not_found
  end

  test "another person's goal, even shared with the household: 404" do
    @goal.share_with(households(:home))
    sign_in identities(:head)

    assert_no_difference -> { Tagging.count } do
      post taggings_path(@goal), params: { name: "ministry" }, as: :turbo_stream
    end
    assert_response :not_found
  end

  private
    def taggings_path(goal)
      household_goal_taggings_path(household_id: households(:home), goal_id: goal)
    end

    def tagging_path(goal, tag)
      household_goal_tagging_path(household_id: households(:home), goal_id: goal, id: tag)
    end
end
