# Writing a week's Get ready cards for children (docs/design/meeting-prep.md, Ai::Purpose::MeetingPrep): one card for
# each part the question asks for. Nobody's text is sent, only the week's dates, the program's address and the parts, so
# there's no moderation check. Its chat is kept 7 days; the cards have their own rule.
class Ai::Purpose::MeetingPrep < Ai::Purpose
  # Lengths and counts go in descriptions: the provider's structured output doesn't enforce them, and the checks before
  # saving run on every reply anyway.
  CARD = { type: "object",
           properties: {
             step: { type: "string", enum: ::PrepWeek::Card::STEPS.keys, description: "One of the parts the message asks for" },
             about: { type: "string", description: "What the part teaches, not what the speaker does: at most 20 words, in short words of your own" },
             quality: { type: "string", enum: ::PrepWeek::Card::QUALITIES.keys, description: "A quality of Jehovah the part really shows" },
             quality_line: { type: "string", description: "How the part shows the quality, in one short sentence of at most 14 words" },
             i_can: { type: "string", description: "One small, kind, safe thing a young child can do this week with her family's help: at most 14 words" },
             reading: { type: "string", description: "Only for bible_reading: the chapters read, like Lamentations 1–2. An empty string for every other part" },
             story: { type: "array", items: { type: "string" },
                      description: "Only for bible_reading: what happens in the reading, in order, in 2 to 4 sentences of at most 14 words each. Empty for every other part" }
           },
           required: %i[ step about quality quality_line i_can reading story ], additionalProperties: false }.freeze

  # The program, the Bible Study chapter and the Watchtower study article are pages of their own.
  def max_searches = 6
  def max_output_tokens = 4_000
  # Per household (docs/design/meeting-prep.md, Ai::Purpose::MeetingPrep).
  def daily_limit = 3
  def keep_for = 7.days
  # Well under the 15 minutes its claim is held, and a timeout fails the run (The weekly AI job).
  def request_timeout = 5.minutes
  def user_block = "meeting_prep_week"

  def schema
    { name: "meeting_prep",
      schema: { type: "object",
                properties: { off_topic: { type: "boolean", description: "True when the message isn't a week to write cards for. Then leave cards empty" },
                              cards: { type: "array", description: "At most one card for each part asked for. Fewer, or none, rather than guess", items: CARD } },
                required: %i[ off_topic cards ], additionalProperties: false } }
  end

  # The week's dates, the parts still missing a card, and the program's address on wol.jw.org, which Aglowy builds but
  # never requests (Trap 1).
  def sent_text(week_of, steps)
    [ "The week: #{week_of.strftime("%A, %B %-d, %Y")} to #{(week_of + 6).strftime("%A, %B %-d, %Y")}",
      "Write cards for: #{steps.join(", ")}",
      "The week's program: #{MeetingNote.program_url(week_of)}" ].join("\n")
  end
end
