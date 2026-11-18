require "test_helper"

class MeetingParts::DraftsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @home = households(:home)
    @part = meeting_parts(:head_conversation)
    @params = { meeting_part_draft: { request: "The person is busy and has a young family." } }
  end

  test "create as a head: an outline draft, its job queued, and the Drafting state" do
    accept_ai_terms(:head)

    assert_difference -> { @part.drafts.count } do
      assert_enqueued_with(job: MeetingPart::WriteDraftJob) do
        post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part), params: @params, as: :turbo_stream
      end
    end

    draft = @part.drafts.sole
    assert_equal [ users(:head), "outline", "The person is busy and has a young family.", "drafting" ], [ draft.user, draft.kind, draft.request, draft.status ]
    assert_response :success
    assert_select "turbo-stream[action=replace][target=ai_panel]"
    assert_includes response.body, "Drafting with AI"
  end

  test "create as an adult on their own part" do
    accept_ai_terms(:spouse)
    part = meeting_parts(:spouse_talk)

    assert_difference -> { part.drafts.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: part), params: @params, as: :turbo_stream
    end
  end

  test "a child is refused" do
    accept_ai_terms(:eli)

    assert_no_difference -> { MeetingPart::Draft.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: meeting_parts(:eli_conversation)), params: @params, as: :turbo_stream
    end

    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]
    assert_no_enqueued_jobs
  end

  test "another person's part is a 404, even shared here" do
    accept_ai_terms(:head)
    meeting_parts(:spouse_talk).share_with(@home)

    assert_no_difference -> { MeetingPart::Draft.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: meeting_parts(:spouse_talk)), params: @params, as: :turbo_stream
    end

    assert_response :not_found
  end

  test "without the terms: refused, nothing created" do
    sign_in identities(:head)

    assert_no_difference -> { MeetingPart::Draft.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part), params: @params, as: :turbo_stream
    end

    assert_response :forbidden
    assert_no_enqueued_jobs
  end

  test "at the limit: Limit reached, nothing created" do
    accept_ai_terms(:head)
    15.times { Ai::Use.create!(user: users(:head), purpose: "meeting_part") }

    assert_no_difference -> { MeetingPart::Draft.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part), params: @params, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_includes response.body, "You've used today's 15 requests"
  end

  test "a request over 500 characters shows Start again with the error, nothing created" do
    accept_ai_terms(:head)

    assert_no_difference [ -> { MeetingPart::Draft.count }, -> { Ai::Use.count } ] do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part), params: { meeting_part_draft: { request: "a" * 501 } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_includes response.body, "is too long"
  end

  test "show: the panel for a reload, and the result as a Turbo Stream once done, nothing while drafting" do
    accept_ai_terms(:head)
    draft = meeting_part_draft(@part)

    get household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: draft), as: :turbo_stream
    assert_response :no_content

    get household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: draft)
    assert_response :success
    assert_select "turbo-frame#ai_panel", text: /Drafting with AI/

    draft.update!(status: "off_topic")
    get household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: draft), as: :turbo_stream
    assert_select "turbo-stream[action=replace][target=ai_panel]"
    assert_includes response.body, "This helper only prepares your meeting part."
  end

  test "show: someone else's draft is a 404" do
    accept_ai_terms(:spouse)
    draft = meeting_part_draft(@part)

    get household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: draft)

    assert_response :not_found
  end

  test "destroy stops a drafting draft, then discards it, and never deletes it" do
    accept_ai_terms(:head)
    draft = meeting_part_draft(@part)

    assert_no_difference [ -> { MeetingPart::Draft.count }, -> { Ai::Use.count } ] do
      delete household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: draft), as: :turbo_stream
      assert_predicate draft.reload, :stopped?
      assert_select "turbo-stream[action=replace][target=ai_panel]"
      assert_includes response.body, "Draft outline"

      delete household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: draft), as: :turbo_stream
      assert_predicate draft.reload, :discarded?
    end
  end

  private
    def accept_ai_terms(identity)
      sign_in identities(identity)
      identities(identity).user.accept_ai_terms(understood: "1")
    end
end
