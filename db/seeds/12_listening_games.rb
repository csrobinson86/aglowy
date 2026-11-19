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

# Lucia has started this week's helper note and found the first Treasures round, so signing in as lucia.rivera and
# opening Today's meeting's Treasures step lands on the second round (docs/design/listening-game.md, Pages).
lucia = seeded_person("lucia.rivera")
game_note = lucia.start_meeting_note(kind: "midweek", week_of:)
first_round = rivera.listening_rounds(week_of, "talk").first
game_note.find_card(first_round.answer) if first_round

# She has written her answer for this week's Congregation Bible Study, so its step shows her answer card with "I gave
# my answer!" (docs/design/listening-game.md, Pages, Her answer). An answer she has already written stays.
game_note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.") unless game_note.answer
