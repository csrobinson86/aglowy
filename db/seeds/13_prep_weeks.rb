# This week's Get ready cards in the Rivera Family, where the helper and Get ready are on (docs/design/meeting-prep.md,
# Models), from the saved reply in test/fixtures/files/ai/ rather than a provider call, through the same checks as a real
# reply. It has no chat, as a week has once its chat is purged. A week the household has cards for stays.
rivera = seeded_household("The Rivera Family", head: "rivera@example.com")
week_of = rivera.today.beginning_of_week(:monday)

unless rivera.prep_weeks.exists?(week_of:)
  body = JSON.parse(Rails.root.join("test/fixtures/files/ai/meeting_prep.json").read)
  results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { { url: it["url"], title: it["title"] } }
  purpose = Ai::Purpose.find("meeting_prep")
  copy_check = Ai::CopyCheck.new(citations: [], overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)

  cards = PrepWeek.cards_from_reply(JSON.parse(body["content"].filter_map { it["text"] }.join), steps: PrepWeek::Card::STEPS.keys, copy_check:)
  rivera.prep_weeks.new(week_of:).fill_in(cards, pages: Ai::SourceLink.keep(results, search_results: results, allowed_hosts: purpose.allowed_hosts), chat: nil)
end
