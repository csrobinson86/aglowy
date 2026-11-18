module DailyBriefsHelper
  # The references in a writing's scripture field, one or several separated by semicolons. The checks kept only ones
  # that parse, so each becomes a scripture link made by Bible::Reference, never by the AI.
  def brief_references(text)
    text.to_s.split(";").filter_map { Bible::Reference.parse(it) }
  end

  # "Verse 21" or "Verses 21-23", for a look-for in the day's reading; "Look for" when it names no verse, as a whole
  # chapter doesn't.
  def verses_label(text)
    verses = Bible::Reference.parse(text)&.then { it.to_s.split(":").last if it.first_verse } or return "Look for"
    verses.match?(/\D/) ? "Verses #{verses}" : "Verse #{verses}"
  end

  # The day's flow under the thread: [text, the section's anchor] for each section the writing wrote, in the brief's
  # order (frame brief-today.png).
  def brief_flow(brief, writing)
    [ ([ "Daily text", "daily-brief-daily-text" ] if brief.section?(:daily_text)),
      (writing.section(:reading)&.dig("passage")&.then { [ it, "daily-brief-reading" ] } if brief.section?(:reading)),
      (writing.section(:quality)&.dig("name")&.then { [ it, "daily-brief-quality" ] } if brief.quality_area),
      ([ brief.appreciation_area.name, "daily-brief-appreciation" ] if brief.appreciation_area && writing.section(:appreciation)),
      ([ "Your focus", "daily-brief-focus" ] if writing.section(:focus) && brief.role_areas.any?),
      (Array(writing.section(:faith)&.dig("examples")).pluck("name").to_sentence(two_words_connector: " and ", last_word_connector: " and ")
         .presence&.then { [ it, "daily-brief-faith" ] } if brief.section?(:faith_example)) ].compact
  end

  # What the Banner says over the parts from the plan when the newest writing ended without a brief.
  def unwritten_message(writing)
    reason = case writing.status
    when "failed" then "Couldn't write today's brief with AI this time."
    when "stopped" then "Writing today's brief was stopped."
    else "The AI couldn't write a brief from this plan."
    end
    "#{reason} Here are the parts from your plan."
  end

  # "Four questions to end the day": the count follows the writing (This evening).
  def evening_title(count)
    "#{DailyBriefs::HomeCardComponent::NUMBER_WORDS.fetch(count, count.to_s).capitalize} #{"question".pluralize(count)} to end the day"
  end

  # "6:00 PM", when the evening questions open in the person's zone.
  def evening_opens_at
    Time.current.change(hour: DailyBrief::EVENING_OPENS_AT).strftime("%-l:%M %p")
  end

  # The section an evening question looks back on, by its name in the brief: the quality's own name, the appreciation
  # focus area's. The AI's own word, escaped, for one it named differently; nothing for none.
  def evening_from(brief, writing, from)
    case from
    when "daily_text" then "Daily text"
    when "reading" then "Bible reading"
    when "quality" then writing.section(:quality)&.dig("name") || brief.quality_area&.name
    when "appreciation" then brief.appreciation_area&.name
    when "focus" then "Your focus"
    when "faith" then "Imitate their faith"
    else from.presence
    end
  end

  # "From this morning": a row for each section the writing wrote, its label beside a few words of what it held.
  def morning_rows(brief, writing)
    row = DailyBriefs::SectionComponent::Row
    [ (row.new(label: "Daily text", text: writing.section(:daily_text)&.dig("reference")) if brief.section?(:daily_text)),
      (row.new(label: "Bible reading", text: writing.section(:reading)&.values_at("passage", "title")&.compact_blank&.join(" · ")) if brief.section?(:reading)),
      (row.new(label: "Quality", text: writing.section(:quality)&.dig("name")) if brief.quality_area),
      (row.new(label: brief.appreciation_area.name, text: writing.section(:appreciation)&.dig("title")) if brief.appreciation_area),
      (row.new(label: "Your focus", text: brief.role_areas.map(&:name).join(", ")) if writing.section(:focus) && brief.role_areas.any?),
      (row.new(label: "Imitate their faith", text: Array(writing.section(:faith)&.dig("examples")).pluck("name")
         .to_sentence(two_words_connector: " and ", last_word_connector: " and ")) if brief.section?(:faith_example)) ].compact
  end

  # The chapter a passage is in, as a reference to link: "Matthew 16" for "Matthew 16:21-23".
  def passage_chapter(text)
    Bible::Reference.parse(text)&.then { Bible::Reference.new(book: it.book, chapter: it.chapter) }
  end
end
