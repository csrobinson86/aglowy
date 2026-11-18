# About how long text takes to say (docs/design/meeting-parts.md, MeetingPart::SpokenLength): words at 130 a minute,
# plus 20 s for each scripture read aloud, rounded to 10 seconds and at least 10 for any words at all. The page's
# spoken_length_controller.js counts and rounds the same way, and the AI aims its drafts at target_words. It's a guide,
# never a reason to refuse a save (Trap 6).
class MeetingPart::SpokenLength
  WORDS_PER_MINUTE = 130
  READ_SECONDS = 20

  # Four fifths of what fits, leaving room for reading scriptures and for pauses.
  def self.target_words(minutes)
    minutes * WORDS_PER_MINUTE * 4 / 5
  end

  # "2 min 40 s", "1 min", "50 s"
  def self.duration(seconds)
    minutes, seconds = seconds.divmod(60)
    [ ("#{minutes} min" if minutes.positive?), ("#{seconds} s" if seconds.positive?) ].compact.join(" ")
  end

  # text is plain text; MeetingPart#spoken_length gives the preparation's as the editor has it.
  def initialize(text, scriptures: 0)
    @words = count_words(text.to_s)
    @scriptures = scriptures
  end

  # Nothing without words or scriptures.
  def seconds
    return if @words.zero? && @scriptures.zero?

    spoken = @words.zero? ? 0 : [ (@words * 60.0 / WORDS_PER_MINUTE / 10).round * 10, 10 ].max
    spoken + @scriptures * READ_SECONDS
  end

  # Blank without words, and the line isn't shown.
  def to_s
    seconds ? "About #{self.class.duration(seconds)} to say" : ""
  end

  # The seconds over the part's minutes, or nil within them.
  def over(minutes)
    excess = seconds.to_i - minutes * 60
    excess if excess.positive?
  end

  private
    # A lone mark, such as a "•" or a dash, isn't a word, so only what holds a letter or a digit counts.
    def count_words(text)
      text.split(/[[:space:]]+/).count { it.match?(/[\p{L}\p{N}]/) }
    end
end
