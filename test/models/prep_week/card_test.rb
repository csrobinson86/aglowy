require "test_helper"

# A Get ready card (docs/design/meeting-prep.md, PrepWeek::Card). Its text is encrypted, so the database can't check its
# lengths: the model does. The fixed values (the step, its meeting and the quality) are checked by the database.
class PrepWeek::CardTest < ActiveSupport::TestCase
  setup do
    @talk = prep_week_cards(:home_nov_9_talk)
    @reading = prep_week_cards(:home_nov_9_bible_reading)
  end

  test "database: the Watchtower Study is on the weekend meeting" do
    assert_raises(ActiveRecord::CheckViolation) { PrepWeek::Card.insert!(row(step: "watchtower_study", meeting: "midweek")) }
  end

  test "database: the midweek steps are on the midweek meeting" do
    assert_raises(ActiveRecord::CheckViolation) { @talk.update_column(:meeting, "weekend") }
  end

  test "database: an unknown meeting" do
    assert_raises(ActiveRecord::CheckViolation) { @talk.update_column(:meeting, "assembly") }
  end

  test "database: an unknown step" do
    assert_raises(ActiveRecord::CheckViolation) { PrepWeek::Card.insert!(row(step: "spiritual_gems")) }
  end

  test "database: a quality outside the ten" do
    assert_raises(ActiveRecord::CheckViolation) { @talk.update_column(:quality, "brave") }
  end

  test "database: a reading on a step that isn't the Bible Reading" do
    assert_raises(ActiveRecord::CheckViolation) { @talk.update_column(:reading, "Lamentations 1–2") }
  end

  test "database: a story on a step that isn't the Bible Reading" do
    assert_raises(ActiveRecord::CheckViolation) { @talk.update_column(:story, "[]") }
  end

  test "database: a second card for a step in the same week" do
    assert_raises(ActiveRecord::RecordNotUnique) { PrepWeek::Card.insert!(row(step: "talk")) }
  end

  test "database: a card needs what it's about" do
    assert_raises(ActiveRecord::NotNullViolation) { @talk.update_column(:about, nil) }
  end

  test "database: a card needs its week" do
    assert_raises(ActiveRecord::NotNullViolation) { @talk.update_column(:prep_week_id, nil) }
  end

  test "the text fields are stored encrypted, and the story reads back as its sentences" do
    @reading.reload

    %i[ about quality_line i_can reading story ].each do |field|
      assert @reading.encrypted_attribute?(field), "#{field} isn't encrypted"
    end
    assert_not_includes @reading.ciphertext_for(:about), "Jerusalem"
    assert_not_includes @reading.ciphertext_for(:story), "Jerusalem"
    assert_equal [ "Jerusalem was the city where Jehovah’s people lived.", "The people stopped listening to Jehovah." ], @reading.story
  end

  test "lengths: about up to 160 characters, quality_line and i_can up to 120, reading up to 40" do
    assert @reading.tap { it.assign_attributes(about: "a" * 160, quality_line: "a" * 120, i_can: "a" * 120, reading: "a" * 40) }.valid?

    @reading.assign_attributes(about: "a" * 161, quality_line: "a" * 121, i_can: "a" * 121, reading: "a" * 41)
    assert_not @reading.valid?
    %i[ about quality_line i_can reading ].each { assert_predicate @reading.errors[it], :any?, "#{it} wasn't refused" }
  end

  test "about, quality_line and i_can can't be blank" do
    @talk.assign_attributes(about: " ", quality_line: "", i_can: nil)

    assert_not @talk.valid?
    %i[ about quality_line i_can ].each { assert_includes @talk.errors[it], "can't be blank" }
  end

  test "a story has at most 4 sentences of at most 120 characters" do
    assert @reading.tap { it.story = [ "a" * 120 ] * 4 }.valid?

    @reading.story = [ "Jeremiah cried." ] * 5
    assert_includes @reading.tap(&:validate).errors[:story], "can have at most 4 sentences"

    @reading.story = [ "a" * 121 ]
    assert_includes @reading.tap(&:validate).errors[:story], "sentences can be at most 120 characters"
  end

  test "each quality has its words and icon" do
    assert_equal 10, PrepWeek::Card::QUALITIES.size
    assert_equal({ words: "Jehovah cares", icon: "heart_plus" }, PrepWeek::Card::QUALITIES.fetch("caring"))
    assert_equal "Jehovah cares", @talk.quality_words
    assert_equal "heart_plus", @talk.quality_icon
  end

  private
    def row(**changes)
      { prep_week_id: @talk.prep_week_id, meeting: "midweek", step: "living", about: "x", quality: "loving", quality_line: "x", i_can: "x" }.merge(changes)
    end
end
