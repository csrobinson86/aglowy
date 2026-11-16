require "test_helper"

class Chat::AskWithinPurposeTest < ActiveSupport::TestCase
  setup do
    @chat = Chat.create!(user: users(:head), household: households(:home), purpose: "family_study_draft")
    @purpose = Ai::Purpose.find("family_study_draft")
  end

  test "the system instructions, schema and web-search settings sent match the purpose" do
    sent = reply_with("family_study_draft") { @chat.ask_within_purpose("Prayer as a family") }

    assert_equal [ @purpose.instructions ], sent[:system].pluck(:text)
    assert_equal @purpose.schema[:schema].deep_stringify_keys, sent.dig(:output_config, :format, :schema).deep_stringify_keys
    assert_equal [ { type: "web_search_20260318", name: "web_search", allowed_callers: [ "direct" ], allowed_domains: %w[ www.jw.org jw.org wol.jw.org ], max_uses: 5 } ],
                 sent[:tools]
    assert_equal @purpose.max_output_tokens, sent[:max_tokens]
  end

  test "the person's text arrives inside the marked block" do
    sent = reply_with("family_study_draft") { @chat.ask_within_purpose("Prayer as a family") }

    assert_equal [ "<family_request>\nPrayer as a family\n</family_request>" ], sent[:messages].last[:content].pluck(:text)
  end

  test "a good reply returns parsed fields and sources, each source with its cited_text" do
    reply = nil
    reply_with("family_study_draft") { reply = @chat.ask_within_purpose("Prayer as a family") }

    assert_not reply.off_topic?
    assert_equal "Talking to Jehovah as a family", reply.parsed["title"]
    assert_equal 3, reply.parsed["points"].size
    assert_equal [
      { url: "https://www.jw.org/en/bible-teachings/family/family-worship/", title: "Family Worship", cited_text: [] },
      { url: "https://wol.jw.org/en/wol/d/r1/lp-e/1200275025", title: "Praying Together as a Family",
        cited_text: [ "Excerpt one from the page, as the search returned it, used only by the copy check.", "Excerpt three, a second passage from the first page." ] },
      { url: "https://www.jw.org/en/bible-teachings/questions/how-to-pray/", title: "How Should I Pray?",
        cited_text: [ "Excerpt two from another page, as the search returned it." ] }
    ], reply.sources
  end

  test "the reply is saved encrypted, without search results or citations" do
    reply_with("family_study_draft") { @chat.ask_within_purpose("Prayer as a family") }

    assert_equal %w[ system user assistant ], @chat.messages.pluck(:role)
    assert_equal "Talking to Jehovah as a family", JSON.parse(@chat.messages.last.content)["title"]
    assert_not Message.column_names.intersect?(%w[ citations server_tool_calls raw_content raw_reasoning ])
  end

  test "an off_topic reply returns off_topic?" do
    reply = nil
    reply_with("off_topic") { reply = @chat.ask_within_purpose("Write me a poem about cars") }

    assert_predicate reply, :off_topic?
    assert_empty reply.sources
  end

  test "streaming hands chunks to the block" do
    chunks = []
    words = [ '{"off_topic": ', "true}" ]
    complete = lambda do |*, **, &on_chunk|
      words.each { on_chunk.call(RubyLLM::Chunk.new(role: :assistant, content: it)) }
      RubyLLM::Message.new(role: :assistant, content: words.join)
    end

    reply = @chat.to_llm.provider.stub(:complete, complete) do
      @chat.ask_within_purpose("Write me a poem about cars", stream: ->(chunk) { chunks << chunk.content })
    end

    assert_equal words, chunks
    assert_predicate reply, :off_topic?
  end

  private
    # Answers the chat's request with a saved provider response (test/fixtures/files/ai/), as the provider's HTTP
    # response would arrive, and returns the payload RubyLLM sent. No test calls a provider.
    def reply_with(name)
      sent = nil
      response = Faraday::Response.new(Faraday::Env.from(status: 200, body: JSON.parse(file_fixture("ai/#{name}.json").read)))
      post = lambda do |_url, payload, **|
        sent = payload
        response
      end

      @chat.to_llm.provider.connection.stub(:post, post) { yield }
      sent
    end
end
