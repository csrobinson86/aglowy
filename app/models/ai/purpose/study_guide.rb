# Writing a person's study guide for a week's two meetings (docs/design/study-guide.md, Ai::Purpose::StudyGuide): a key
# for each step, with the fields StudyGuide::Part::Shape gives it, filled in only for the steps the question asks for. Nobody's text is sent,
# only the week's dates, the program's address and the steps, so there's no moderation check. Its chat is kept 7 days;
# the guide has its own rule.
class Ai::Purpose::StudyGuide < Ai::Purpose
  # Lengths and counts go in descriptions: the provider's structured output doesn't enforce them, and the checks before
  # saving run on every reply anyway.
  TEXTS = {
    "glance" => "This week's meeting at a glance, in your own words",
    "title" => "The part's title as the program gives it",
    "summary" => "What the part covers, in your own words",
    "reading" => "The chapters read, like Lamentations 1–2",
    "text" => "One point, in your own words",
    "quality" => "A quality of Jehovah the material really shows, like Merciful",
    "paragraphs" => "The paragraphs the note covers, like 4–7",
    "paragraph" => "The paragraph the comment is for, like 5"
  }.freeze
  LISTS = {
    "jehovah" => "About Jehovah: what the material really shows about him",
    "points" => "The talk's main points",
    "comments" => "Comment ideas: short, in the first person, things a person could say",
    "happens" => "What happens in the reading, in order",
    "teaches" => "What the reading teaches about Jehovah",
    "apply" => "How we can apply it",
    "notes" => "Notes on what the paragraphs cover, in order"
  }.freeze
  REF = { type: "string", description: "The point's scripture as a reference, like Lamentations 2:17 or Psalm 23. An empty string when it has none" }.freeze

  # The program, the reading, the Bible Study chapter and the Watchtower study article.
  def max_searches = 8
  def max_output_tokens = 8_000
  # Per person, counted where they live (docs/design/study-guide.md, Ai::Purpose::StudyGuide).
  def daily_limit = 2
  def keep_for = 7.days
  # Well under the 15 minutes its claim is held, and a timeout fails the run (The weekly job).
  def request_timeout = 5.minutes
  def user_block = "study_guide_week"

  # One fixed key per step, as the daily brief has per section, and no anyOf: strict structured output compiles a union
  # of the steps' shapes into one grammar, which Anthropic rejected as too large (#432).
  def schema
    { name: "study_guide",
      schema: object(off_topic: { type: "boolean", description: "True when the message isn't a week to write a study guide for. Then leave every step empty" },
                     **::StudyGuide::Part::STEPS.keys.to_h { [ it.to_sym, step(it) ] }) }
  end

  # The week's dates, the steps still missing a part, and the program's address on wol.jw.org, which Aglowy builds but
  # never requests (Trap 1).
  def sent_text(week_of, steps)
    [ "The week: #{week_of.strftime("%A, %B %-d, %Y")} to #{(week_of + 6).strftime("%A, %B %-d, %Y")}",
      "Write parts for: #{steps.join(", ")}",
      "The week's program: #{MeetingNote.program_url(week_of)}" ].join("\n")
  end

  private
    def object(description: nil, **properties)
      { type: "object", description:, properties:, required: properties.keys, additionalProperties: false }.compact
    end

    def step(name)
      shape = ::StudyGuide::Part::Shape.new(name)
      object(description: "The #{name} step, only when the message asks for it. Otherwise leave its fields empty: empty strings and lists. Empty, too, rather than guess",
             **shape.texts.to_h { [ it.to_sym, text(it) ] }, **shape.lists.to_h { |list_name, (counts, label)| [ list_name.to_sym, list(list_name, counts, label) ] })
    end

    def text(name)
      { type: "string", description: "#{TEXTS.fetch(name)}: at most #{::StudyGuide::Part::Shape::WORDS.fetch(name)} words" }
    end

    def list(name, counts, label)
      point = { text: text("text"), ref: REF }
      point = { label.to_sym => text(label), **point } if label
      { type: "array", description: "#{counts.min.zero? ? "Up to #{counts.max}" : "#{counts.min} to #{counts.max}"}. #{LISTS.fetch(name)}",
        items: { type: "object", properties: point, required: point.keys, additionalProperties: false } }
    end
end
