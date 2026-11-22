# Saved AI replies

Provider responses for the AI tests (`docs/design/ai.md`, Traps: tests never call a provider). Each file is the
JSON body of one Anthropic Messages API response; `reply_with` in `test/models/chat/ask_within_purpose_test.rb`
hands it to RubyLLM as the HTTP response would arrive.

- `family_study_draft.json`: a good draft with three search results and citations carrying `cited_text`.
  **Hand-built** in Anthropic's documented shape (story #180 had no working key). Replace it with a recorded reply.
- `off_topic.json`: a refusal with no search. Hand-built.
- `personal_study_answer.json`: a personal study answer with three search results, linked references and three next
  questions. Hand-built, like the draft.
- `personal_study_not_found.json`: a personal study answer with a `not_found` note, one paragraph and one search
  result. Hand-built.
- `meeting_part_outline.json`: a meeting part outline (`outline` filled, `wording` empty) with three search results and
  two citations carrying `cited_text`. Hand-built, like the draft. The seeds use it too, for the drafted outline.
- `meeting_part_wording.json`: sample wording for a conversation (`wording` filled, `outline` empty): 8 lines, one with a
  scripture to read, the same three search results and one citation carrying `cited_text`. Hand-built. The seeds use it
  for the drafted wording.
- `daily_brief.json`: a daily brief for Tuesday 17 November 2026 with every section filled, three search results (the
  day's text on wol.jw.org among them) and one citation carrying `cited_text`. Hand-built. The seeds use it too, for the
  written brief.
- `listening_game.json`: the listening game cards for the week of 16–22 November 2026: 5 Treasures rounds, 2 Spiritual
  Gems, 1 Bible Reading and 6 Congregation Bible Study, every label written for the fixture, never taken from jw.org.
  Three search results (the week's program among them) and two citations carrying `cited_text`, one naming a page the
  search never returned, which `Ai::SourceLink` drops. Hand-built. The seeds use it too, for this week's game.
- `meeting_prep.json`: the Get ready cards for the week of 16–22 November 2026, one for each of the five parts, with the
  Bible Reading's four-sentence story, every word written for the fixture (the design's example cards), never taken from
  jw.org. Three search results (the week's program and the Watchtower study article among them) and two citations
  carrying `cited_text`, one naming a page the search never returned, which `Ai::SourceLink` drops. Hand-built. The seeds
  use it too, for this week's cards.
- `study_guide.json`: a study guide for the week of 16–22 November 2026, a part for each of the nine steps, every word
  written for the fixture (the design's example frames, with the bracketed placeholders filled in), never taken from
  jw.org. Four search results (the week's program, the reading, the Bible Study chapter and the Watchtower study article)
  and two citations carrying `cited_text`, one naming a page the search never returned, which `Ai::SourceLink` drops.
  Hand-built. The seeds use it too, for Hannah's guide this week.

## Recording a reply

With `AI_MODEL` and a working `ANTHROPIC_API_KEY` in `.env.development`, run this once from `bin/rails console`.
It rolls back what it writes and calls the provider once (up to 5 searches):

```ruby
body = nil
RubyLLM::Transport::Connection.prepend(Module.new do
  define_method(:post) { |*args, **opts, &blk| super(*args, **opts, &blk).tap { body = it.body } }
end)
ActiveRecord::Base.transaction do
  Chat.create!(user: User.first, purpose: "family_study_draft").ask_within_purpose("Prayer as a family")
  raise ActiveRecord::Rollback
end
File.write("test/fixtures/files/ai/family_study_draft.json", JSON.pretty_generate(body) + "\n")
```

Check that the citations carry `cited_text`, then replace every `cited_text` with a placeholder like the ones in
the hand-built file: the repository never keeps jw.org or wol.jw.org text. Shorten each `encrypted_content` and
`encrypted_index` to a placeholder too, and update the expected title, points and sources in the test.
