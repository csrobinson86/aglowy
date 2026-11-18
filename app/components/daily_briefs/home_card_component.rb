# frozen_string_literal: true

# The person's own daily brief at the top of Home (docs/design/daily-brief.md, On Home; frame brief-home.png): the
# thread, the reading, the quality and the faith example, and Open today's brief. Written by AI, the AI's words from its
# newest written writing; otherwise what the brief's own copy of the plan gives for today, and no thread. A section
# that's off, or a box the plan leaves for the brief to choose, leaves its fact out. Every field is escaped.
class DailyBriefs::HomeCardComponent < ApplicationComponent
  Fact = Data.define(:label, :value)

  # The writing has 3 or 4 evening questions (The reply).
  NUMBER_WORDS = %w[ no one two three four ].freeze

  attr_reader :brief, :href, :writing

  def initialize(brief:, href:)
    @brief, @href, @writing = brief, href, brief.writing
  end

  def thread
    writing&.section(:thread)
  end

  def facts
    [ (Fact.new("Reading", reading) if brief.section?(:reading)),
      (Fact.new("Quality", quality) if brief.quality_area),
      (Fact.new("Imitate their faith", examples) if brief.section?(:faith_example)) ].compact.select { it.value.present? }
  end

  # "About 10 minutes.", and the evening's questions when the writing has them. Nothing for the parts from the plan.
  def note
    return unless writing

    questions = brief.evening_questions.size
    [ "About 10 minutes.", ("This evening it has #{NUMBER_WORDS.fetch(questions, questions)} questions to end the day." if questions.positive?) ].compact.join(" ")
  end

  private
    def reading
      writing&.section(:reading)&.dig("passage") || brief.day.reading
    end

    def quality
      writing&.section(:quality)&.dig("name") || brief.topic_for(brief.quality_area)
    end

    def examples
      names = Array(writing&.section(:faith)&.dig("examples")).pluck("name")
      names.to_sentence(two_words_connector: " and ", last_word_connector: " and ").presence || brief.day.examples
    end
end
