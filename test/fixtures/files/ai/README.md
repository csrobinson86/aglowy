# Saved AI replies

Provider responses for the AI tests (`docs/design/ai.md`, Traps: tests never call a provider). Each file is the
JSON body of one Anthropic Messages API response; `reply_with` in `test/models/chat/ask_within_purpose_test.rb`
hands it to RubyLLM as the HTTP response would arrive.

- `family_study_draft.json`: a good draft with three search results and citations carrying `cited_text`.
  **Hand-built** in Anthropic's documented shape (story #180 had no working key). Replace it with a recorded reply.
- `off_topic.json`: a refusal with no search. Hand-built.

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
