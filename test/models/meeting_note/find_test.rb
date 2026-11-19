require "test_helper"

class MeetingNote::FindTest < ActiveSupport::TestCase
  setup do
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    @round = listening_game_rounds(:home_talk_first)
  end

  test "finding the answer card copies its label and kind, and keeps them when the card changes" do
    find = @note.find_card(listening_game_cards(:home_talk_jeremiah))

    listening_game_cards(:home_talk_jeremiah).update!(label: "Jonah", kind: "place")

    assert_equal [ "talk", 1, "Jeremiah", "person" ], find.reload.values_at(:step, :position, :label, :kind)
  end

  test "a find outlives the game" do
    @note.find_card(listening_game_cards(:home_talk_jeremiah))

    listening_games(:home_nov_9).destroy!

    assert_equal [ "Jeremiah" ], @note.reload.finds_for("talk").map(&:label)
  end

  test "another card makes no find" do
    assert_no_difference -> { MeetingNote::Find.count } do
      assert_nil @note.find_card(listening_game_cards(:home_talk_noah))
    end
  end

  test "finding the answer twice makes one find" do
    assert_difference -> { @note.finds.count }, 1 do
      2.times { @note.find_card(listening_game_cards(:home_talk_jeremiah)) }
    end
  end

  test "found_count counts every step's finds, and finds_for lists a step's in round order" do
    second = listening_round("talk", 2, answer: "Ruth", others: %w[ Esther Joseph David ])
    gems = listening_round("spiritual_gems", 1, answer: "Manna", others: %w[ Ark Lamp Coat ], kind: "thing")
    @note.find_card(second.answer)
    @note.find_card(gems.answer)
    @note.find_card(@round.answer)

    assert_equal 3, @note.found_count
    assert_equal %w[ Jeremiah Ruth ], @note.finds_for("talk").map(&:label)
    assert @note.found?(second)
    assert_not @note.found?(listening_round("talk", 3, answer: "Elijah", others: %w[ Abel Adam Eve ]))
  end

  test "a note with no finds counts none" do
    assert_equal 0, @note.found_count
  end

  test "database: deleting a note deletes its finds" do
    @note.find_card(@round.answer)

    assert_difference -> { MeetingNote::Find.count }, -1 do
      MeetingNote.where(id: @note.id).delete_all
    end
  end

  test "database: a find without a label raises NotNullViolation" do
    find = @note.find_card(@round.answer)

    assert_raises(ActiveRecord::NotNullViolation) { find.update_column(:label, nil) }
  end

  test "database: a find without a kind raises NotNullViolation" do
    find = @note.find_card(@round.answer)

    assert_raises(ActiveRecord::NotNullViolation) { find.update_column(:kind, nil) }
  end

  test "database: a find without a step raises NotNullViolation" do
    find = @note.find_card(@round.answer)

    assert_raises(ActiveRecord::NotNullViolation) { find.update_column(:step, nil) }
  end

  test "database: a find without a position raises NotNullViolation" do
    find = @note.find_card(@round.answer)

    assert_raises(ActiveRecord::NotNullViolation) { find.update_column(:position, nil) }
  end

  test "database: a find for a missing note raises InvalidForeignKey" do
    find = @note.find_card(@round.answer)

    assert_raises(ActiveRecord::InvalidForeignKey) { find.update_column(:meeting_note_id, SecureRandom.uuid_v7) }
  end

  test "database: the unique index rejects a second find for a round" do
    @note.find_card(@round.answer)

    assert_raises ActiveRecord::RecordNotUnique do
      MeetingNote::Find.insert!({ meeting_note_id: @note.id, step: "talk", position: 1, label: "Noah", kind: "person" })
    end
  end
end
