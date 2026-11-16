require "test_helper"

class AiAcceptancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @form_path = new_household_family_study_path(household_id: households(:home), ai_panel: "open")
  end

  test "creates an acceptance and returns to the form" do
    sign_in identities(:head)

    assert_difference -> { users(:head).ai_acceptances.count } do
      post ai_acceptance_path(return_to: @form_path), params: { ai_acceptance: { understood: "1" } }
    end

    assert_redirected_to @form_path
    assert_predicate users(:head), :accepted_ai_terms?
  end

  test "ignores a return_to outside the person's households" do
    sign_in identities(:head)

    [ new_household_family_study_path(household_id: households(:other)), "https://evil.example/#{households(:home).id}", "//evil.example", nil ].each do |return_to|
      post ai_acceptance_path(return_to: return_to), params: { ai_acceptance: { understood: "1" } }

      assert_redirected_to households_path, "expected #{return_to.inspect} to be ignored"
    end
  end

  test "without the box ticked: nothing recorded, and the form says why" do
    sign_in identities(:head)

    assert_no_difference -> { Ai::Acceptance.count } do
      post ai_acceptance_path(return_to: @form_path), params: { ai_acceptance: { understood: "0" } }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=ai_terms]"
    assert_includes response.body, "Tick “I understand how AI drafts work” to turn on AI drafts"
    assert_includes response.body, "Not now"
  end

  test "without the box ticked from a personal study, the form comes back without Not now" do
    study_path = household_personal_study_path(household_id: households(:home), id: personal_studies(:head_suffering))
    sign_in identities(:head)

    post ai_acceptance_path(return_to: study_path, not_now: false), params: { ai_acceptance: { understood: "0" } }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_includes response.body, "not_now=false"
    assert_not_includes response.body, "Not now"
  end

  test "signed out redirects to sign in" do
    assert_no_difference -> { Ai::Acceptance.count } do
      post ai_acceptance_path(return_to: @form_path), params: { ai_acceptance: { understood: "1" } }
    end

    assert_redirected_to new_identity_session_path
  end
end
