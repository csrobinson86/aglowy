# Drafting a family study (docs/design/family-studies.md, AI helper). The reply fields are FamilyStudy::Draft's.
class Ai::Purpose::FamilyStudyDraft < Ai::Purpose
  # Lengths and counts go in descriptions: the provider's structured output doesn't enforce them, and the checks in
  # docs/design/ai.md run on every reply anyway.
  TEXT = { type: "string", description: "300 characters at most" }.freeze
  SCRIPTURE = { type: "string", description: "One Bible reference as plain text, like Philippians 4:6, 7. Never verse text" }.freeze

  def max_searches = 5
  def max_output_tokens = 4_000
  def daily_limit = 10

  def schema
    {
      name: "family_study_draft",
      schema: {
        type: "object",
        properties: {
          off_topic: { type: "boolean", description: "True when the request isn't for planning a family study. Then leave every other field empty" },
          title: TEXT,
          opening: section(scripture: SCRIPTURE, question: TEXT),
          points: { type: "array", description: "2 to 4 points", items: section(heading: TEXT, scripture: SCRIPTURE, question: TEXT) },
          children: { type: "string", description: "One activity for young children, only when the request asks for one; otherwise empty. 300 characters at most" },
          closing: TEXT
        },
        required: %i[ off_topic title opening points children closing ],
        additionalProperties: false
      }
    }
  end

  private
    def section(**properties)
      { type: "object", properties: properties, required: properties.keys, additionalProperties: false }
    end
end
