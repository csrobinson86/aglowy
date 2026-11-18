require "test_helper"

class MeetingPart::SpokenLengthTest < ActiveSupport::TestCase
  def words(count)
    ([ "word" ] * count).join(" ")
  end

  test "no words: no seconds and a blank to_s" do
    [ "", "  \n ", nil, "• " ].each do |text|
      spoken_length = MeetingPart::SpokenLength.new(text)

      assert_nil spoken_length.seconds
      assert_equal "", spoken_length.to_s
      assert_nil spoken_length.over(3)
    end
  end

  test "5 words: 10 s; 108 words: 50 s; 347 words: 2 min 40 s; exactly 130 words: 1 min" do
    assert_equal 10, MeetingPart::SpokenLength.new(words(5)).seconds
    assert_equal "About 10 s to say", MeetingPart::SpokenLength.new(words(5)).to_s
    assert_equal 50, MeetingPart::SpokenLength.new(words(108)).seconds
    assert_equal "About 50 s to say", MeetingPart::SpokenLength.new(words(108)).to_s
    assert_equal 160, MeetingPart::SpokenLength.new(words(347)).seconds
    assert_equal "About 2 min 40 s to say", MeetingPart::SpokenLength.new(words(347)).to_s
    assert_equal 60, MeetingPart::SpokenLength.new(words(130)).seconds
    assert_equal "About 1 min to say", MeetingPart::SpokenLength.new(words(130)).to_s
  end

  test "any words at all are at least 10 s" do
    assert_equal 10, MeetingPart::SpokenLength.new("Hello").seconds
  end

  test "words are split on any space, and a lone mark isn't a word" do
    assert_equal 10, MeetingPart::SpokenLength.new("One\ntwo\n\n• three").seconds
    assert_equal MeetingPart::SpokenLength.new(words(108)).seconds,
                 MeetingPart::SpokenLength.new("• #{words(54)}\n• #{words(54)}").seconds
  end

  test "over is nil at the part's minutes and under, and the seconds over above it" do
    assert_nil MeetingPart::SpokenLength.new(words(390)).over(3) # 3 min exactly
    assert_nil MeetingPart::SpokenLength.new(words(108)).over(3)
    assert_equal 40, MeetingPart::SpokenLength.new(words(477)).over(3) # 3 min 40 s
  end

  test "scriptures to read add READ_SECONDS each" do
    assert_equal 50 + 2 * MeetingPart::SpokenLength::READ_SECONDS, MeetingPart::SpokenLength.new(words(108), scriptures: 2).seconds
    assert_equal MeetingPart::SpokenLength::READ_SECONDS, MeetingPart::SpokenLength.new("", scriptures: 1).seconds
  end

  test "target_words(3) is four fifths of 390" do
    assert_equal 312, MeetingPart::SpokenLength.target_words(3)
    assert_equal 390 * 4 / 5, MeetingPart::SpokenLength.target_words(3)
  end

  test "130 words a minute, and 20 s for each scripture read aloud" do
    assert_equal 130, MeetingPart::SpokenLength::WORDS_PER_MINUTE
    assert_equal 20, MeetingPart::SpokenLength::READ_SECONDS
  end
end
