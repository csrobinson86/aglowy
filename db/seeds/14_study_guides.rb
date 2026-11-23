# Hannah has turned on AI features and her study guide, so Settings → You → Study guide shows it ticked
# (docs/design/study-guide.md, The Settings section; frame phone-guide-settings.png). Sam hasn't accepted the AI terms,
# so his shows the disabled box and the line saying where to accept them. Turning it on again keeps the one row.
hannah = seeded_person("head@example.com")
seeded!(hannah.accept_ai_terms(understood: "1"))
hannah.turn_on_study_guide || raise("Hannah's study guide wasn't turned on")

# Daniel, an adult in the Rivera Family, has his study guide on too. Accepting the terms asks for the Riveras' Get ready
# cards, which db/seeds.rb drops while seeding.
daniel = seeded_person("daniel.rivera@example.com")
seeded!(daniel.accept_ai_terms(understood: "1"))
daniel.turn_on_study_guide || raise("Daniel's study guide wasn't turned on")

# Daniel's study guide for this week, the Monday where he lives (docs/design/study-guide.md, The weekly job; frames
# desktop-guide-midweek.png, desktop-guide-weekend.png), from the three saved replies in test/fixtures/files/ai/, one per
# group of steps, rather than provider calls, through the same checks as a real reply. It has no chat, as a guide has
# once its chat is purged. A week he has a guide for stays.
week_of = Time.current.in_time_zone(daniel.limit_time_zone).to_date.beginning_of_week(:monday)

unless daniel.study_guides.exists?(week_of:)
  purpose = Ai::Purpose.find("study_guide")
  copy_check = Ai::CopyCheck.new(citations: [], overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)
  guide = daniel.study_guides.new(week_of:)

  Ai::Purpose::StudyGuide::GROUPS.each do |group, steps|
    body = JSON.parse(Rails.root.join("test/fixtures/files/ai/study_guide_#{group}.json").read)
    results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { { url: it["url"], title: it["title"] } }

    parts = StudyGuide.parts_from_reply(JSON.parse(body["content"].filter_map { it["text"] }.join), steps:, copy_check:)
    guide.fill_in(parts, pages: Ai::SourceLink.keep(results, search_results: results, allowed_hosts: purpose.allowed_hosts), chat: nil)
  end
end
