require "test_helper"

class FamilyStudy::SessionTest < ActiveSupport::TestCase
  test "upcoming is from now, in order, without cancelled sessions" do
    assert_equal family_study_sessions(:weekly_next, :one_off_first, :weekly_later), FamilyStudy::Session.upcoming.to_a
  end

  test "preloaded loads the study" do
    assert FamilyStudy::Session.preloaded.first.association(:family_study).loaded?
  end

  test "a second session in the same slot is a validation error" do
    taken = family_study_sessions(:weekly_next)
    session = taken.family_study.sessions.new(recurrence_at: taken.recurrence_at, scheduled_at: 1.year.from_now)

    assert_not session.valid?
    assert_includes session.errors[:recurrence_at], "has already been taken"
  end

  test "requires recurrence_at and scheduled_at" do
    session = FamilyStudy::Session.new

    assert_not session.valid?
    assert_includes session.errors[:recurrence_at], "can't be blank"
    assert_includes session.errors[:scheduled_at], "can't be blank"
  end

  test "database: a duplicate family_study_id and recurrence_at raises RecordNotUnique" do
    taken = family_study_sessions(:weekly_next)

    assert_raises ActiveRecord::RecordNotUnique do
      FamilyStudy::Session.insert!({ family_study_id: taken.family_study_id, recurrence_at: taken.recurrence_at, scheduled_at: 1.year.from_now })
    end
  end

  test "database: a session without a family_study_id raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_study_sessions(:weekly_next).update_column(:family_study_id, nil) }
  end

  test "database: a session without a recurrence_at raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_study_sessions(:weekly_next).update_column(:recurrence_at, nil) }
  end

  test "database: a session without a scheduled_at raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { family_study_sessions(:weekly_next).update_column(:scheduled_at, nil) }
  end

  test "database: a session for a missing study raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { family_study_sessions(:weekly_next).update_column(:family_study_id, SecureRandom.uuid_v7) }
  end

  test "database: a session with a missing conductor raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { family_study_sessions(:weekly_next).update_column(:conductor_id, SecureRandom.uuid_v7) }
  end
end
