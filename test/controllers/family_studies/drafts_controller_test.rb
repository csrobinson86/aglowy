require "test_helper"

class FamilyStudies::DraftsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @household = households(:home)
    @params = { family_study_draft: { prompt: "Trusting Jehovah when we feel anxious", length_minutes: "45", young_children: "1" } }
  end

  test "head with acceptance: creates a draft and enqueues the job" do
    accept_ai_terms(:head)

    assert_difference -> { @household.family_study_drafts.count } do
      assert_enqueued_with(job: FamilyStudy::WriteDraftJob) do
        post household_family_study_drafts_path(household_id: @household), params: @params, as: :turbo_stream
      end
    end

    draft = @household.family_study_drafts.last
    assert_equal [ users(:head), "Trusting Jehovah when we feel anxious", 45, true, "drafting" ], [ draft.user, draft.prompt, draft.length_minutes, draft.young_children, draft.status ]
    assert_response :success
    assert_select "turbo-stream[action=replace][target=ai_panel]"
    assert_includes response.body, "Drafting with AI"
  end

  test "an adult with acceptance may draft too" do
    accept_ai_terms(:spouse)

    assert_difference -> { @household.family_study_drafts.count } do
      post household_family_study_drafts_path(household_id: @household), params: @params, as: :turbo_stream
    end
  end

  test "without acceptance: 403, nothing created" do
    sign_in identities(:head)

    assert_no_difference -> { FamilyStudy::Draft.count } do
      post household_family_study_drafts_path(household_id: @household), params: @params, as: :turbo_stream
    end

    assert_response :forbidden
    assert_no_enqueued_jobs
  end

  test "an acceptance of an older version doesn't count" do
    sign_in identities(:head)
    Ai::Acceptance.create!(user: users(:head), version: Rails.configuration.x.ai.terms_version - 1, understood: "1")

    assert_no_difference -> { FamilyStudy::Draft.count } do
      post household_family_study_drafts_path(household_id: @household), params: @params, as: :turbo_stream
    end

    assert_response :forbidden
  end

  test "child: refused" do
    accept_ai_terms(:eli)

    assert_no_difference -> { FamilyStudy::Draft.count } do
      post household_family_study_drafts_path(household_id: @household), params: @params, as: :turbo_stream
    end

    assert_redirected_to household_root_path(household_id: @household)
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "another household: 404" do
    accept_ai_terms(:head)

    assert_no_difference -> { FamilyStudy::Draft.count } do
      post household_family_study_drafts_path(household_id: households(:other)), params: @params, as: :turbo_stream
    end

    assert_response :not_found
  end

  test "11th of the day: Limit reached, nothing created" do
    accept_ai_terms(:head)
    10.times { family_study_draft(household: @household) }

    assert_no_difference -> { FamilyStudy::Draft.count } do
      post household_family_study_drafts_path(household_id: @household), params: @params, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=ai_panel]"
    assert_includes response.body, "You've used today's 10 drafts"
    assert_no_enqueued_jobs
  end

  test "blank prompt: re-renders with the error" do
    accept_ai_terms(:head)

    assert_no_difference -> { FamilyStudy::Draft.count } do
      post household_family_study_drafts_path(household_id: @household),
        params: { family_study_draft: @params[:family_study_draft].merge(prompt: "") }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=ai_panel]"
    assert_includes response.body, "What should the study be about?"
    assert_includes response.body, "can&#39;t be blank"
  end

  test "a request with only the prompt still starts a draft, for older children" do
    accept_ai_terms(:head)

    post household_family_study_drafts_path(household_id: @household), params: { family_study_draft: { prompt: "Prayer", length_minutes: "30" } }, as: :turbo_stream

    assert_response :success
    assert_not @household.family_study_drafts.sole.young_children
  end

  private
    def accept_ai_terms(identity)
      sign_in identities(identity)
      identities(identity).user.accept_ai_terms(understood: "1")
    end
end
