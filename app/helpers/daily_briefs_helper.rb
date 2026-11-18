module DailyBriefsHelper
  # The references in a writing's scripture field, one or several separated by semicolons. The checks kept only ones
  # that parse, so each becomes a scripture link made by Bible::Reference, never by the AI.
  def brief_references(text)
    text.to_s.split(";").filter_map { Bible::Reference.parse(it) }
  end

  # The brief's sections by name, each a DailyBriefs::SectionComponent, nil for one that's off (The brief): the AI's words
  # from its newest written writing where it wrote that section, and the parts from the plan, from the brief's own copy,
  # where it didn't. The Daily text keeps the AI's words only when it read that day's page (check 4); otherwise it's the
  # link alone. The page draws them, and Keep in Notes writes them into the note.
  def brief_sections(brief, writing)
    { daily_text: (daily_text_section(brief, writing&.section(:daily_text)) if brief.section?(:daily_text)),
      reading: (reading_section(brief, writing&.section(:reading)) if brief.section?(:reading)),
      quality: brief.quality_area&.then { quality_section(brief, it, writing&.section(:quality)) },
      appreciation: brief.appreciation_area&.then { appreciation_section(brief, it, writing&.section(:appreciation)) },
      focus: (focus_section(brief, writing&.section(:focus)) if brief.role_areas.any?),
      faith: (faith_section(brief, writing&.section(:faith)) if brief.section?(:faith_example)) }
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

  def daily_text_section(brief, text)
    DailyBriefs::SectionComponent.new(kicker: "Daily text", title: text&.dig("reference") || brief.on.strftime("%A, %B %-d"),
      link: brief_link("Open #{text ? "today's text" : "the Daily text"} on wol.jw.org", brief.daily_text_url, "the text and its comment are read there"),
      rows: text ? [ brief_row("What's happening", text["happening"]), brief_row("What it teaches me about Jehovah", text["teaches"]),
                     brief_row("How I can use it today", text["apply"], brief_references(text["apply_scripture"])) ] : [])
  end

  def reading_section(brief, reading)
    day = brief.day
    if reading
      chapter = passage_chapter(reading["passage"])
      DailyBriefs::SectionComponent.new(kicker: [ "Bible reading", ("from #{day.reading}" if day.reading.present?) ].compact.join(" · "),
        id: "daily-brief-reading", title: [ reading["passage"], reading["title"] ].compact.join(" · ").presence || day.reading.presence || "Today's reading",
        link: (brief_link("Read #{chapter} on jw.org", chapter.jw_url, "what to look for as you read:") if chapter),
        rows: Array(reading["look_for"]).map { brief_row(verses_label(it["verses"]), it["text"]) })
    else
      DailyBriefs::SectionComponent.new(kicker: "Bible reading", title: day.reading, id: "daily-brief-reading", rows: [
        brief_row("From your week", brief.reading_start ? "Pick up where you left off, or start at" : "Pick up where you left off, or choose a chapter.",
                  [ brief.reading_start ].compact) ])
    end
  end

  def quality_section(brief, area, quality)
    if quality
      DailyBriefs::SectionComponent.new(kicker: area.name, title: quality["name"] || area.name, id: "daily-brief-quality", rows: [
        brief_row("What it is", quality["what"], brief_references(quality["what_scripture"])),
        brief_row("How Jesus showed it", quality["jesus"], brief_references(quality["jesus_scripture"])), brief_row("One way today", quality["today"]) ])
    else
      topic = brief.topic_for(area)
      DailyBriefs::SectionComponent.new(kicker: area.name, title: topic || area.name, id: "daily-brief-quality",
        rows: [ brief_row("From your week", topic ? "#{brief.day.name}'s qualities." : area.gives, area.scripture_references) ])
    end
  end

  def appreciation_section(brief, area, appreciation)
    if appreciation
      DailyBriefs::SectionComponent.new(kicker: area.name, title: appreciation["title"] || area.name, id: "daily-brief-appreciation", rows: [
        brief_row("Seen today", appreciation["seen"], brief_references(appreciation["scripture"])), brief_row("Think about", appreciation["think"]) ])
    else
      DailyBriefs::SectionComponent.new(kicker: area.name, title: brief.topic_for(area) || "One thing to thank him for", id: "daily-brief-appreciation",
        rows: [ brief_row("Think about", "What did I see of him in my reading today?", area.scripture_references) ])
    end
  end

  # "Your focus today": one row per role focus area, in the plan's order, the AI's where it wrote one, each with its linked
  # goal under it, from Aglowy's own data.
  def focus_section(brief, focus)
    DailyBriefs::SectionComponent.new(kicker: "Your focus today", title: focus ? "One thing in each role" : "From your plan", id: "daily-brief-focus",
      rows: brief.role_areas.each_with_index.map { |area, index|
        note = brief.linked_goals[area.id]&.then { goal_note(it) }
        if (written = focus&.dig(index)&.presence)
          brief_row(area.name, written["action"], brief_references(written["scripture"]), note:)
        else
          brief_row(area.name, (topic = brief.topic_for(area)) ? "#{topic}." : area.gives, area.scripture_references, note:)
        end })
  end

  # "Your goal: Qualify as a ministerial servant · next step: Ask an elder where I can help", or the goal alone when every
  # step is done.
  def goal_note(goal)
    [ "Your goal: #{goal.title}", goal.progress.next_step&.then { "next step: #{it.title}" } ].compact.join(" · ")
  end

  def faith_section(brief, faith)
    if faith
      examples = Array(faith["examples"])
      DailyBriefs::SectionComponent.new(kicker: "Imitate their faith", id: "daily-brief-faith",
        title: examples.pluck("name").to_sentence(two_words_connector: " and ", last_word_connector: " and ").presence || brief.day.examples.presence || "For me",
        rows: examples.map { brief_row(it["name"], it["lesson"], brief_references(it["scriptures"])) } + [ brief_row("For me", faith["for_me"]) ])
    else
      DailyBriefs::SectionComponent.new(kicker: "Imitate their faith", title: brief.day.examples, id: "daily-brief-faith",
        rows: [ brief_row("From your week", "#{brief.day.name}'s examples.") ])
    end
  end

  def brief_row(label, text, references = [], note: nil)
    DailyBriefs::SectionComponent::Row.new(label:, text:, references:, note:)
  end

  def brief_link(text, href, note)
    DailyBriefs::SectionComponent::Link.new(text:, href:, note:)
  end

  # A reference as Action Text stores a scripture link, for Keep in Notes' body (docs/design/scripture-links.md).
  def scripture_attachment(reference)
    content_tag(ActionText::Attachment.tag_name, nil, sgid: reference.attachable_sgid, "content-type": reference.attachable_content_type)
  end

  # A section's title for Keep in Notes' body, each part that's a whole reference, "Matthew 16" in "Matthew 16 · Title",
  # a scripture link: Bible::Linker links a chapter and verse only, so a whole chapter would stay text.
  def note_title(title)
    safe_join(title.to_s.split(" · ").map { |part| Bible::Reference.parse(part)&.then { scripture_attachment(it) } || part }, " · ")
  end

  # The chapter a passage is in, as a reference to link: "Matthew 16" for "Matthew 16:21-23".
  def passage_chapter(text)
    Bible::Reference.parse(text)&.then { Bible::Reference.new(book: it.book, chapter: it.chapter) }
  end
end
