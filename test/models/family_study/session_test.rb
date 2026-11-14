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

  test "rescheduling sets scheduled_at in the household zone and detached_at" do
    households(:home).update!(time_zone: "Tokyo")
    session = family_study_sessions(:weekly_next)
    recurrence_at = session.recurrence_at

    freeze_time do
      session.reschedule(on: Date.new(2027, 3, 14), at: Time.zone.parse("18:30"))

      assert_equal Time.utc(2027, 3, 14, 9, 30), session.reload.scheduled_at
      assert_equal Time.current, session.detached_at
      assert_equal recurrence_at, session.recurrence_at
    end
  end

  test "rescheduling to the time it already has doesn't detach" do
    session = family_study_sessions(:weekly_next)

    session.reschedule(on: session.local_scheduled_at.to_date, at: session.local_scheduled_at)

    assert_nil session.reload.detached_at
  end

  test "a topic-only edit doesn't detach" do
    session = family_study_sessions(:weekly_next)
    scheduled_at = session.scheduled_at

    assert FamilyStudy::Session::Edit.new(session, topic: "Imitate Their Faith, chapter 4").save

    session.reload
    assert_equal "Imitate Their Faith, chapter 4", session.topic
    assert_equal scheduled_at, session.scheduled_at
    assert_nil session.detached_at
  end

  test "an edit with a new date or time reschedules and detaches" do
    session = family_study_sessions(:weekly_next)
    new_day = session.local_scheduled_at.to_date + 1

    assert FamilyStudy::Session::Edit.new(session, topic: "", starts_on: new_day.iso8601, starts_at: "20:15").save

    session.reload
    assert_nil session.topic
    assert_equal ActiveSupport::TimeZone[households(:home).time_zone].local(new_day.year, new_day.month, new_day.day, 20, 15), session.scheduled_at
    assert session.detached_at
  end

  test "an edit without a date or time is invalid and changes nothing" do
    session = family_study_sessions(:weekly_next)
    edit = FamilyStudy::Session::Edit.new(session, topic: "Ruth 2", starts_on: "", starts_at: "")

    assert_not edit.save
    assert_includes edit.errors[:starts_on], "can't be blank"
    assert_includes edit.errors[:starts_at], "can't be blank"
    assert_nil session.reload.topic
  end

  test "an edit starts from the session's topic, date and time in the household's zone" do
    households(:home).update!(time_zone: "Tokyo")
    session = family_study_sessions(:one_off_first)
    edit = FamilyStudy::Session::Edit.new(session)

    assert_equal "Draw Close to Jehovah, chapter 1", edit.topic
    assert_equal session.local_scheduled_at.to_date, edit.starts_on
    assert_equal session.local_scheduled_at.strftime("%H:%M"), edit.starts_at.strftime("%H:%M")
  end

  test "cancel sets canceled_at and restore clears it" do
    session = family_study_sessions(:weekly_next)

    freeze_time do
      session.cancel
      assert_equal Time.current, session.reload.canceled_at
    end

    session.restore
    assert_nil session.reload.canceled_at
  end

  test "the generator doesn't recreate a rescheduled or cancelled session" do
    travel_to Date.new(2026, 11, 14) do
      study = households(:home).schedule_family_study(frequency: "weekly", starts_on: Date.current, time_of_day: "19:00")
      moved = study.sessions.find_by!(recurrence_at: study.session_time_on(Date.new(2026, 11, 21)))
      canceled = study.sessions.find_by!(recurrence_at: study.session_time_on(Date.new(2026, 11, 28)))

      moved.reschedule(on: Date.new(2026, 11, 22), at: Time.zone.parse("10:00"))
      canceled.cancel

      assert_no_difference -> { study.sessions.count } do
        study.extend_sessions
      end
      assert_not study.sessions.exists?(scheduled_at: moved.recurrence_at)
      assert_predicate canceled.reload, :canceled?
    end
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
