# This week's listening game in the Rivera Family, where the meeting helper is on (docs/design/listening-game.md,
# Models), from the saved reply in test/fixtures/files/ai/ rather than a provider call, through the same checks as a
# real reply. It has no chat, as a game has once its chat is purged. A game the household has for the week stays.
rivera = seeded_household("The Rivera Family", head: "rivera@example.com")
week_of = rivera.today.beginning_of_week(:monday)

unless rivera.listening_games.exists?(week_of:)
  body = JSON.parse(Rails.root.join("test/fixtures/files/ai/listening_game.json").read)
  results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { { url: it["url"], title: it["title"] } }
  purpose = Ai::Purpose.find("listening_game")
  copy_check = Ai::CopyCheck.new(citations: [], overlap_words: purpose.copy_overlap_words, quote_max_words: purpose.quote_max_words)

  ListeningGame.build_from_reply(JSON.parse(body["content"].filter_map { it["text"] }.join),
                                 sources: Ai::SourceLink.keep(results, search_results: results, allowed_hosts: purpose.allowed_hosts),
                                 copy_check:, household: rivera, week_of:).save!
end
