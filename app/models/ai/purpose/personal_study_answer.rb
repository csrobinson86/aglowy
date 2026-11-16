# Answering a question in someone's personal study (docs/design/personal-study.md, PersonalStudy::Question). The reply
# fields are the question's answer. Counted per person, from Ai::Use rows in their own time zone.
class Ai::Purpose::PersonalStudyAnswer < Ai::Purpose
  # Lengths and counts go in descriptions: the provider's structured output doesn't enforce them, and the checks in
  # docs/design/ai.md run on every reply anyway.
  def max_searches = 5
  def max_output_tokens = 3_000
  def daily_limit = 30
  # The chat grows with each question, so only the latest go with a new one (Traps).
  def context_exchanges = 10
  def user_block = "study_question"

  def schema
    {
      name: "personal_study_answer",
      schema: {
        type: "object",
        properties: {
          off_topic: { type: "boolean", description: "True when the question isn't about the Bible or spiritual study. Then leave every other field empty" },
          not_found: { type: "boolean", description: "True when jw.org and wol.jw.org don't address the question" },
          not_found_note: { type: "string", description: "Only when not_found: one sentence saying so, starting “I couldn't find jw.org or wol.jw.org…”; otherwise empty" },
          paragraphs: { type: "array", description: "0 to 5 paragraphs, each 600 characters at most, in your own words. Scripture references as plain text, like Philippians 4:6, 7",
                        items: { type: "string" } },
          next_questions: { type: "array", description: "Up to 3 questions to study next, each 120 characters at most", items: { type: "string" } }
        },
        required: %i[ off_topic not_found not_found_note paragraphs next_questions ],
        additionalProperties: false
      }
    }
  end
end
