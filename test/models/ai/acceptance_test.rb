require "test_helper"

class Ai::AcceptanceTest < ActiveSupport::TestCase
  test "accepting with the box ticked records the current terms version" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_predicate acceptance, :persisted?
    assert_equal Rails.configuration.x.ai.terms_version, acceptance.version
    assert_predicate users(:head), :accepted_ai_terms?
  end

  test "accepting without the box ticked records nothing" do
    acceptance = users(:head).accept_ai_terms(understood: "0")

    assert_not acceptance.persisted?
    assert_equal [ "Tick “I understand how AI drafts work” to turn on AI drafts" ], acceptance.errors[:understood]
    assert_not users(:head).accepted_ai_terms?
  end

  test "accepting twice keeps one record" do
    users(:head).accept_ai_terms(understood: "1")

    assert_no_difference -> { Ai::Acceptance.count } do
      assert_predicate users(:head).accept_ai_terms(understood: "1"), :persisted?
    end
  end

  test "the database refuses a second acceptance of the same version" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_raises(ActiveRecord::RecordNotUnique) { Ai::Acceptance.insert!({ user_id: acceptance.user_id, version: acceptance.version }) }
  end

  test "the database refuses an acceptance without a version" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_raises(ActiveRecord::NotNullViolation) { acceptance.update_column(:version, nil) }
  end

  test "the database refuses an acceptance without a person" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_raises(ActiveRecord::NotNullViolation) { acceptance.update_column(:user_id, nil) }
  end
end
