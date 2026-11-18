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

  OUTLINE = { "aim" => "Leave the person curious.", "opening" => "Say hello.", "points" => [ { "heading" => "A promise worth hearing", "explain" => "It speaks of peace." } ] }.freeze

  test "create with kind: wording" do
    accept_ai_terms(:head)

    assert_enqueued_with(job: MeetingPart::WriteDraftJob) do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part), params: { meeting_part_draft: { kind: "wording", request: "" } }, as: :turbo_stream
    end

    draft = @part.drafts.sole
    assert_equal [ "wording", nil, nil ], [ draft.kind, draft.request, draft.revises ]
    assert_includes response.body, "Drafting with AI"
    assert_includes response.body, "Writing the sample wording"
  end

  test "create a change: a new draft revising the one shown" do
    accept_ai_terms(:head)
    shown = meeting_part_draft(@part, status: "drafted", result: OUTLINE)

    assert_difference -> { @part.drafts.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part),
        params: { meeting_part_draft: { kind: "outline", revises_id: shown.id, request: "Shorter opening" } }, as: :turbo_stream
    end

    change = @part.drafts.order(:created_at).last
    assert_equal [ "outline", shown, "Shorter opening", OUTLINE ], [ change.kind, change.revises, change.request, change.revised_result ]
    assert_response :success
  end

  test "write sample wording from an outline" do
    accept_ai_terms(:head)
    outline = meeting_part_draft(@part, status: "drafted", result: OUTLINE)

    post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part),
      params: { meeting_part_draft: { kind: "wording", revises_id: outline.id } }, as: :turbo_stream

    assert_equal [ "wording", outline ], @part.drafts.order(:created_at).last.then { [ it.kind, it.revises ] }
  end

  test "a blank change shows the draft again with the error, nothing created" do
    accept_ai_terms(:head)
    shown = meeting_part_draft(@part, status: "drafted", result: OUTLINE)

    assert_no_difference -> { MeetingPart::Draft.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part),
        params: { meeting_part_draft: { kind: "outline", revises_id: shown.id, request: " " } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Leave the person curious."
    assert_includes response.body, "can&#39;t be blank"
  end

  test "a change to a draft that's been discarded is refused with a Banner" do
    accept_ai_terms(:head)
    gone = meeting_part_draft(@part, status: "discarded", result: OUTLINE)

    assert_no_difference -> { MeetingPart::Draft.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part),
        params: { meeting_part_draft: { kind: "outline", revises_id: gone.id, request: "Shorter opening" } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_includes response.body, "That draft can&#39;t be changed now."
  end

  test "a kind that isn't outline or wording is refused, and Start shows again" do
    accept_ai_terms(:head)

    assert_no_difference -> { MeetingPart::Draft.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part), params: { meeting_part_draft: { kind: "summary" } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Draft outline"
  end

  test "revises pointing at another person's draft is a 404" do
    accept_ai_terms(:head)
    theirs = meeting_part_draft(meeting_parts(:spouse_talk), status: "drafted", result: OUTLINE)

    assert_no_difference -> { MeetingPart::Draft.count } do
      post household_meeting_part_drafts_path(household_id: @home, meeting_part_id: @part),
        params: { meeting_part_draft: { kind: "outline", revises_id: theirs.id, request: "Shorter opening" } }, as: :turbo_stream
    end

    assert_response :not_found
  end

  test "show an earlier version" do
    accept_ai_terms(:head)
    version1 = meeting_part_draft(@part, status: "drafted", result: OUTLINE.merge("aim" => "The first version's aim."))
    version2 = meeting_part_draft(@part, status: "drafted", revises: version1, revised_result: version1.result, request: "Simpler words",
                                         result: OUTLINE.merge("aim" => "The second version's aim."))

    get household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: version1)

    assert_select "turbo-frame#ai_panel", text: /The first version's aim\./
    assert_select "turbo-frame#ai_panel", text: /Version 1 of the outline/
    assert_not_includes response.body, "The second version's aim."

    get household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: version2)
    assert_select "a[href='#{household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: version1)}']", text: "See version 1"
  end

  test "discarding a change shows Start without the change in the box" do
    accept_ai_terms(:head)
    shown = meeting_part_draft(@part, status: "drafted", result: OUTLINE)
    change = meeting_part_draft(@part, status: "drafted", revises: shown, revised_result: OUTLINE, request: "Shorter opening", result: OUTLINE)

    delete household_meeting_part_draft_path(household_id: @home, meeting_part_id: @part, id: change), as: :turbo_stream

    assert_includes response.body, "Draft outline"
    assert_not_includes response.body, "Shorter opening"
  end

  private
    def accept_ai_terms(identity)
      sign_in identities(identity)
      identities(identity).user.accept_ai_terms(understood: "1")
    end
end
