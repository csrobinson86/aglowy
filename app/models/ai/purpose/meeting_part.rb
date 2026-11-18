# Preparing a student part in Apply Yourself to the Field Ministry (docs/design/meeting-parts.md, Prepare with AI). One
# schema holds both shapes, an outline and sample wording; the draft's kind says which the instructions ask for, and the
# other is left empty. Counted per person, from Ai::Use rows in their own time zone.
class Ai::Purpose::MeetingPart < Ai::Purpose
  # Lengths and counts go in descriptions: the provider's structured output doesn't enforce them, and the checks in
  # docs/design/ai.md run on every reply anyway.
  TEXT = { type: "string", description: "500 characters at most" }.freeze
  SCRIPTURE = { type: "string", description: "One Bible reference as plain text, like Psalm 37:10, 11, or empty. Never verse text" }.freeze

  def max_searches = 5
  def max_output_tokens = 4_000
  def daily_limit = 15
  # Each draft is its own chat, so the purge takes a draft 60 days after it was asked for (safety measure 10).
  def keep_for = 60.days
  def user_block = "meeting_part"

  def schema
    {
      name: "meeting_part",
      schema: object(
        off_topic: { type: "boolean", description: "True when the request isn't for preparing this meeting part. Then leave every other field empty" },
        outline: object(
          aim: TEXT, opening: TEXT,
          points: { type: "array", description: "1 to 3 points", items: object(heading: TEXT, scripture: SCRIPTURE, explain: TEXT) },
          question: { type: "string", description: "One question to ask, or to leave for next time; empty for a talk. 500 characters at most" },
          close: TEXT,
          study_point: { type: "string", description: "How to work on the study point given; empty when none is given. 500 characters at most" }
        ),
        wording: object(
          lines: { type: "array", description: "2 to 20 lines",
                   items: object(speaker: { type: "string", enum: %w[ you other ] }, text: TEXT,
                                 read: { type: "string", description: "A scripture to read aloud after the line, as a plain-text reference, or empty. Never verse text" }) }
        )
      )
    }
  end

  private
    def object(**properties)
      { type: "object", properties: properties, required: properties.keys, additionalProperties: false }
    end
end
