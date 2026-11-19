# Finding a week's listening game cards (docs/design/listening-game.md, What it asks): for each of the four midweek game
# steps, the rounds in the order the part covers them. Nobody's text is sent, only the week's dates and the program's
# address, so there's no moderation check. Its chat is kept 7 days; the game has its own rule.
class Ai::Purpose::ListeningGame < Ai::Purpose
  # Lengths and counts go in descriptions: the provider's structured output doesn't enforce them, and the checks before
  # saving run on every reply anyway.
  CARD = { type: "object",
           properties: { label: { type: "string", description: "At most 4 words and 40 characters, in child words of your own" },
                         kind: { type: "string", enum: ::ListeningGame::Card::KINDS } },
           required: %i[ label kind ], additionalProperties: false }.freeze

  # The Bible Study chapter is a page of its own, so one more than the others.
  def max_searches = 6
  def max_output_tokens = 4_000
  # Per household (docs/design/listening-game.md, What it asks).
  def daily_limit = 3
  def keep_for = 7.days
  # Well under the 15 minutes its claim is held, and a timeout fails the run (When it runs).
  def request_timeout = 5.minutes
  def user_block = "listening_game_week"

  def schema
    rounds = ::ListeningGame::ROUNDS.to_h do |step, most|
      [ step.to_sym, { type: "array", description: "0 to #{most} rounds, in the order the part covers them", items: round } ]
    end

    { name: "listening_game",
      schema: { type: "object",
                properties: { off_topic: { type: "boolean", description: "True when the message isn't a week to find cards for. Then leave every list empty" }, **rounds },
                required: [ :off_topic, *rounds.keys ], additionalProperties: false } }
  end

  # The week's dates and its program's address on wol.jw.org, which Aglowy builds but never requests (Trap 1).
  def sent_text(week_of)
    [ "The midweek meeting's week: #{week_of.strftime("%A, %B %-d, %Y")} to #{(week_of + 6).strftime("%A, %B %-d, %Y")}",
      "The week's program: #{MeetingNote.program_url(week_of)}" ].join("\n")
  end

  private
    def round
      { type: "object",
        properties: { answer: CARD, others: { type: "array", description: "Exactly 3 cards the part doesn't mention", items: CARD } },
        required: %i[ answer others ], additionalProperties: false }
    end
end
