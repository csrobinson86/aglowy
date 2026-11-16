require "test_helper"

class Ai::UseTest < ActiveSupport::TestCase
  test "purged after 2 days" do
    old = travel_to(49.hours.ago) { Ai::Use.create!(user: users(:head), purpose: "personal_study") }
    recent = travel_to(47.hours.ago) { personal_study_question.use }

    Ai::PurgeExpiredUsesJob.perform_now

    assert_not Ai::Use.exists?(old.id)
    assert Ai::Use.exists?(recent.id)
  end

  test "deleting the person deletes their uses" do
    personal_study_question

    assert_difference -> { Ai::Use.count }, -1 do
      users(:head).destroy!
    end
  end

  test "database: a question has one use at most" do
    use = Ai::Use.create!(user: users(:head), purpose: "personal_study")

    assert_raises(ActiveRecord::RecordNotUnique) { use.update_column(:question_id, personal_study_question.id) }
  end

  test "database: an unknown purpose raises CheckViolation" do
    use = Ai::Use.create!(user: users(:head), purpose: "personal_study")

    assert_raises(ActiveRecord::CheckViolation) { use.update_column(:purpose, "chatbot") }
  end

  test "database: a use needs a person" do
    use = Ai::Use.create!(user: users(:head), purpose: "personal_study")

    assert_raises(ActiveRecord::NotNullViolation) { use.update_column(:user_id, nil) }
  end
end
