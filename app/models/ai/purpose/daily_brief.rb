# Writing a person's daily brief from their own plan (docs/design/daily-brief.md, The AI part). One schema, a field per
# section; a section the plan has off is left empty and ignored. Counted per person, from Ai::Use rows in their own
# time zone. What's sent is built here, from the brief's own copy of the plan, so nothing else can slip in (Trap 2).
class Ai::Purpose::DailyBrief < Ai::Purpose
  # Lengths and counts go in descriptions: the provider's structured output doesn't enforce them, and the checks in
  # docs/design/ai.md run on every reply anyway.
  TEXT = { type: "string", description: "300 characters at most" }.freeze
  SCRIPTURE = { type: "string", description: "One Bible reference as plain text, like Philippians 4:6, 7, or empty. Never verse text" }.freeze
  # The most earlier briefs on the same weekday whose choices are sent, so the next brief doesn't repeat them.
  EARLIER = 8

  def max_searches = 6
  def max_output_tokens = 6_000
  def daily_limit = 3
  # Each writing is its own chat, so the purge takes a writing 60 days after it was asked for (safety measure 10).
  def keep_for = 60.days
  def user_block = "daily_brief"

  def schema
    {
      name: "daily_brief",
      schema: object(
        off_topic: { type: "boolean", description: "True when the request isn't for writing this daily brief. Then leave every other field empty" },
        thread: { type: "string", description: "One sentence that ties the day together, 200 characters at most" },
        daily_text: object(reference: SCRIPTURE, happening: TEXT, teaches: TEXT, apply: TEXT, apply_scripture: SCRIPTURE),
        reading: object(passage: SCRIPTURE, title: TEXT,
                        look_for: { type: "array", description: "1 to 3 things to look for", items: object(verses: SCRIPTURE, text: TEXT) }),
        quality: object(name: TEXT, what: TEXT, what_scripture: SCRIPTURE, jesus: TEXT, jesus_scripture: SCRIPTURE, today: TEXT),
        appreciation: object(title: TEXT, seen: TEXT, scripture: SCRIPTURE, think: TEXT),
        focus: { type: "array", description: "One per role focus area, in the plan's order", items: object(action: TEXT, scripture: SCRIPTURE) },
        faith: object(
          examples: { type: "array", description: "1 or 2 examples",
                      items: object(name: TEXT, lesson: TEXT,
                                    scriptures: { type: "string", description: "Bible references as plain text, separated by semicolons. Never verse text" }) },
          for_me: TEXT
        ),
        children: object(ask: TEXT, today: TEXT),
        evening: { type: "array", description: "3 or 4 questions to end the day",
                   items: object(text: TEXT, from: { type: "string", enum: %w[ daily_text reading quality appreciation focus faith ] }) }
      )
    }
  end

  # The date, which sections are on, each focus area and the day's row from the brief's copy, as the person typed them,
  # and what earlier briefs on this weekday chose. Never the person's name, a household, a goal or a note.
  def sent_text(brief)
    day = brief.day
    [ "Date: #{brief.on.strftime("%A, %B %-d, %Y")}", "The day's text: #{brief.daily_text_url}", "Sections on: #{brief.sections.join(", ")}",
      "Focus areas:", *brief.focus_areas.map { focus_area_text(brief, it) },
      "The day's reading: #{day.reading.presence || "you choose"}", "The day's faith examples: #{day.examples.presence || "you choose"}",
      *earlier_text(brief) ].join("\n")
  end

  # Everything the person typed that's sent, together, for the moderation check.
  def typed_text(brief)
    areas = brief.focus_areas.flat_map { [ it.name, it.gives, it.scriptures, brief.topic_for(it) ] }
    [ *areas, brief.day.reading, brief.day.examples ].compact_blank.join("\n")
  end

  private
    def object(**properties)
      { type: "object", properties: properties, required: properties.keys, additionalProperties: false }
    end

    def focus_area_text(brief, area)
      [ "- #{area.name} (#{area.kind}). What I want from it: #{area.gives}", ("Scriptures: #{area.scriptures}" if area.scriptures.present?),
        ("Today's topic: #{brief.topic_for(area)}" if brief.topic_for(area)) ].compact.join(". ")
    end

    # The passages, qualities and examples the person's last briefs on this weekday used, as references and names only.
    def earlier_text(brief)
      results = earlier_briefs(brief).filter_map { it.writing&.result }
      used = { "Passages" => results.filter_map { it.dig("reading", "passage") },
               "Qualities" => results.filter_map { it.dig("quality", "name") },
               "Faith examples" => results.flat_map { Array(it.dig("faith", "examples")).filter_map { it["name"] } } }.compact_blank
      return [] if used.empty?

      [ "Used on earlier #{brief.on.strftime("%A")}s, so choose others:", *used.map { |label, names| "#{label}: #{names.uniq.join("; ")}" } ]
    end

    def earlier_briefs(brief)
      brief.user.daily_briefs.where(on: ...brief.on).where(%(extract(dow from daily_briefs."on") = ?), brief.on.wday)
           .order(on: :desc).limit(EARLIER).includes(:writings)
    end
end
