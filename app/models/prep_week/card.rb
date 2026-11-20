# A Get ready card for one part of a meeting (docs/design/meeting-prep.md, PrepWeek::Card): what the part is about, a
# quality of Jehovah it shows and how, and one thing she can do; the Bible Reading card adds its reading and a short
# story. The AI writes it and a head or adult can change it, so its text is encrypted and its lengths are checked here,
# because the database sees the ciphertext. Untrusted text: always escaped when shown (Trap 4).
class PrepWeek::Card < ApplicationRecord
  # The parts that get a card, in the helper's step order, and their meeting.
  # Keep in step with the prep_week_cards_step_check and prep_week_cards_step_meeting_check constraints.
  STEPS = { "talk" => "midweek", "bible_reading" => "midweek", "living" => "midweek",
            "congregation_bible_study" => "midweek", "watchtower_study" => "weekend" }.freeze
  # Jehovah's qualities: the AI picks a key, and the words and icon are ours (Trap 3).
  # Keep in step with the prep_week_cards_quality_check constraint.
  QUALITIES = {
    "loving" => { words: "Jehovah is loving", icon: "heart" },
    "caring" => { words: "Jehovah cares", icon: "heart_plus" },
    "kind" => { words: "Jehovah is kind", icon: "open_hand" },
    "wise" => { words: "Jehovah is wise", icon: "light_bulb" },
    "fair" => { words: "Jehovah is fair", icon: "scales" },
    "strong" => { words: "Jehovah is strong", icon: "mountain" },
    "patient" => { words: "Jehovah is patient", icon: "hourglass" },
    "generous" => { words: "Jehovah gives", icon: "gift" },
    "forgiving" => { words: "Jehovah forgives", icon: "turn_back" },
    "faithful" => { words: "Jehovah keeps his promises", icon: "shield_check" }
  }.freeze
  # The columns' lengths, for every card, a parent's change too.
  LENGTHS = { about: 160, quality_line: 120, i_can: 120, reading: 40 }.freeze
  STORY_SENTENCES = 4
  SENTENCE_LENGTH = 120
  # The schema's limits, on what the AI returns only.
  REPLY_WORDS = { about: 20, quality_line: 14, i_can: 14 }.freeze
  REPLY_STORY_SENTENCES = 2..4
  REPLY_SENTENCE_WORDS = 14

  belongs_to :prep_week
  belongs_to :changed_by, class_name: "User", optional: true

  serialize :story, coder: JSON
  encrypts :about, :quality_line, :i_can, :reading, :story

  validates :about, :quality_line, :i_can, presence: true
  LENGTHS.each { |field, most| validates field, length: { maximum: most } }
  validate :story_fits

  # A card's attributes from a reply's { step, about, quality, quality_line, i_can, reading, story }, or nil when it
  # fails the checks before saving (docs/design/meeting-prep.md): a known step and quality; about, quality_line and
  # i_can each 1 word to the schema's limit and within its column; a reading and a story of 2 to 4 sentences on the
  # Bible Reading card, and neither on any other; nothing the copy check removes, except a story sentence, which goes
  # on its own, as long as 2 are left.
  def self.attributes_from_reply(card, copy_check:)
    return unless card.is_a?(Hash) && card["step"].in?(STEPS) && card["quality"].in?(QUALITIES)

    texts = REPLY_WORDS.to_h { |field, most| [ field, text_from_reply(card[field.to_s], words: most, length: LENGTHS[field], copy_check:) ] }
    reading = card["step"] == "bible_reading" ? reading_from_reply(card, copy_check:) : no_reading_in_reply(card)
    { step: card["step"], meeting: STEPS[card["step"]], quality: card["quality"], **texts, **reading } if texts.values.all? && reading
  end

  def quality_words
    QUALITIES.fetch(quality)[:words]
  end

  def quality_icon
    QUALITIES.fetch(quality)[:icon]
  end

  class << self
    private
      # The text squished, or nil unless it's a string of 1 to +words+ words (runs of non-whitespace), within +length+
      # characters, that the copy check leaves alone.
      def text_from_reply(text, length:, words: nil, copy_check:)
        text = text.squish if text.is_a?(String)
        text if text.is_a?(String) && text.split.size.in?(1..words) && text.length <= length && !copy_check.clean(text).last
      end

      def reading_from_reply(card, copy_check:)
        reading = text_from_reply(card["reading"], length: LENGTHS[:reading], copy_check:)
        story = story_from_reply(card["story"], copy_check:)
        { reading:, story: } if reading && story
      end

      def no_reading_in_reply(card)
        { reading: nil, story: nil } if card["reading"].blank? && card["story"].blank?
      end

      # 2 to 4 sentences, each 1 to 14 words within its length, without those the copy check removes; nil when fewer
      # than 2 are left.
      def story_from_reply(story, copy_check:)
        return unless story.is_a?(Array) && story.size.in?(REPLY_STORY_SENTENCES) && story.all?(String)

        sentences = story.map(&:squish)
        return unless sentences.all? { it.split.size.in?(1..REPLY_SENTENCE_WORDS) && it.length <= SENTENCE_LENGTH }

        sentences.reject { copy_check.clean(it).last }.then { it if it.size >= REPLY_STORY_SENTENCES.min }
      end
  end

  private
    def story_fits
      return if story.nil?

      errors.add(:story, "can have at most #{STORY_SENTENCES} sentences") if story.size > STORY_SENTENCES
      errors.add(:story, "sentences can be at most #{SENTENCE_LENGTH} characters") if story.any? { it.to_s.length > SENTENCE_LENGTH }
    end
end
