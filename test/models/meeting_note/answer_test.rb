require "test_helper"

class MeetingNote::AnswerTest < ActiveSupport::TestCase
  setup do
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
  end

  test "writing an answer, then changing it, keeps one answer" do
    @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")

    assert_no_difference -> { MeetingNote::Answer.count } do
      @note.reload.write_answer(paragraph: 8, body: "Jesus was kind.")
    end
    assert_equal [ 8, "Jesus was kind." ], @note.reload.answer.values_at(:paragraph, :body)
  end

  test "a refused answer comes back with its errors and saves nothing" do
    answer = @note.write_answer(paragraph: 7, body: " ")

    assert_includes answer.errors[:body], "can't be blank"
    assert_nil @note.reload.answer
  end

  test "a refused change keeps the answer before it" do
    @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")

    answer = @note.reload.write_answer(paragraph: 0, body: "Jesus was kind.")

    assert_includes answer.errors[:paragraph], "must be greater than 0"
    assert_equal 7, @note.reload.answer.paragraph
  end

  test "an answer of 500 characters is fine, 501 is too long" do
    assert @note.build_answer(paragraph: 1, body: "a" * 500).valid?

    answer = @note.build_answer(paragraph: 1, body: "a" * 501)
    assert_not answer.valid?
    assert_includes answer.errors[:body], "is too long (maximum is 500 characters)"
  end

  test "a paragraph that isn't a whole number from 1 to 999 is refused" do
    [ 0, -1, 1.5, 1_000, nil ].each do |paragraph|
      assert_not @note.build_answer(paragraph:, body: "Jesus was kind.").valid?, "#{paragraph.inspect} was allowed"
    end
  end

  test "the body is encrypted at rest" do
    answer = @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")
    raw = MeetingNote::Answer.connection.select_value(MeetingNote::Answer.where(id: answer.id).select(:body).to_sql)

    assert_not_includes raw, "Jehovah helps"
    assert_equal "Jehovah helps us when we are sad.", answer.reload.body
  end

  test "with an answer, the Bible Study step's mark button says I gave my answer!" do
    study, talk = @note.helper_steps.fetch("congregation_bible_study"), @note.helper_steps.fetch("talk")
    assert_equal [ "I watched!", "Watched it" ], [ @note.mark_label(study), @note.marked_label(study) ]

    @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")

    assert_equal [ "I gave my answer!", "Gave my answer" ], [ @note.mark_label(study), @note.marked_label(study) ]
    assert_equal [ "I heard it!", "Heard it" ], [ @note.mark_label(talk), @note.marked_label(talk) ]
  end

  test "only the Congregation Bible Study takes an answer" do
    assert_equal [ "congregation_bible_study" ], @note.helper_steps.select(&:answerable?).map(&:key)
    assert_empty MeetingNote::HelperSteps.for("weekend").select(&:answerable?)
  end

  test "database: deleting a note deletes its answer" do
    @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")

    assert_difference -> { MeetingNote::Answer.count }, -1 do
      MeetingNote.where(id: @note.id).delete_all
    end
  end

  test "database: an answer without a body raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { MeetingNote::Answer.insert!({ meeting_note_id: @note.id, paragraph: 7, body: nil }) }
  end

  test "database: an answer without a paragraph raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { MeetingNote::Answer.insert!({ meeting_note_id: @note.id, paragraph: nil, body: "Jesus was kind." }) }
  end

  test "database: paragraph 0 raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { MeetingNote::Answer.insert!({ meeting_note_id: @note.id, paragraph: 0, body: "Jesus was kind." }) }
  end

  test "database: an answer for a missing note raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { MeetingNote::Answer.insert!({ meeting_note_id: SecureRandom.uuid_v7, paragraph: 7, body: "Jesus was kind." }) }
  end

  test "database: the unique index rejects a second answer for a note" do
    @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")

    assert_raises(ActiveRecord::RecordNotUnique) { MeetingNote::Answer.insert!({ meeting_note_id: @note.id, paragraph: 8, body: "Jesus was kind." }) }
  end
end
