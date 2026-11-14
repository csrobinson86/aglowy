require "test_helper"

class FamilyStudy::SessionTest < ActiveSupport::TestCase
  test "upcoming is from now, in order, without cancelled sessions" do
    assert_equal family_study_sessions(:weekly_next, :one_off_first, :weekly_later), FamilyStudy::Session.upcoming.to_a
  end

  test "ahead is from now, in order, cancelled sessions included" do
    assert_equal family_study_sessions(:weekly_next, :one_off_first, :weekly_cancelled, :weekly_later), FamilyStudy::Session.ahead.to_a
  end

  test "preloaded loads the study and its household" do
    session = FamilyStudy::Session.preloaded.first

    assert session.association(:family_study).loaded?
    assert session.family_study.association(:household).loaded?
  end

  test "canceled? when canceled_at is set" do
    assert family_study_sessions(:weekly_cancelled).canceled?
    assert_not family_study_sessions(:weekly_next).canceled?
  end

  test "local_scheduled_at is scheduled_at in the household's zone" do
    households(:home).update!(time_zone: "Tokyo")
    session = family_study_sessions(:weekly_next)

    assert_equal "Tokyo", session.local_scheduled_at.time_zone.name
    assert_equal session.scheduled_at, session.local_scheduled_at
  end

  test "local_ends_at is the study's duration after local_scheduled_at" do
    households(:home).update!(time_zone: "Tokyo")
    session = family_study_sessions(:weekly_next)

    assert_equal "Tokyo", session.local_ends_at.time_zone.name
    assert_equal session.scheduled_at + 45.minutes, session.local_ends_at
  end

  test "notes are stored encrypted" do
    session = family_study_sessions(:weekly_next)
    session.update!(notes: "<p>Ask everyone about Ruth's loyalty</p>")

    raw = ActionText::RichText.connection.select_value(
      ActionText::RichText.where(record: session, name: "notes").select(:body).to_sql
    )

    assert_not_includes raw, "Ruth's loyalty"
    assert_includes session.reload.notes.to_plain_text, "Ask everyone about Ruth's loyalty"
  end

  test "notes get a UUIDv7 id, like every other record" do
    session = family_study_sessions(:weekly_next)
    session.update!(notes: "<p>Ruth 1</p>")

    assert_equal "7", session.notes.id[14]
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

  test "add_files counts the files together against the quota, and adds none when they don't fit" do
    pdf, photo = direct_uploaded_blob("study-guide.pdf"), direct_uploaded_blob("photo.png")
    use_home_storage(households(:home).storage_quota - pdf.byte_size - photo.byte_size + 1)

    resources = assert_no_difference("FamilyStudy::Resource.count") { family_study_sessions(:weekly_next).add_files([ pdf.signed_id, photo.signed_id ]) }

    assert_empty resources.first.errors
    assert_equal [ "Your household has used its 2 GB of file storage. Remove some files to add more." ], resources.last.errors[:base]
  end

  test "add_files adds none when they don't fit, even inside a transaction of the caller's" do
    pdf, photo = direct_uploaded_blob("study-guide.pdf"), direct_uploaded_blob("photo.png")
    use_home_storage(households(:home).storage_quota - pdf.byte_size - photo.byte_size + 1)

    assert_no_difference("FamilyStudy::Resource.count") do
      FamilyStudy::Session.transaction { family_study_sessions(:weekly_next).add_files([ pdf.signed_id, photo.signed_id ]) }
    end
  end
end
