require "test_helper"

class Ai::ReplyTest < ActiveSupport::TestCase
  test "a reply cut off before its JSON ends raises instead of passing as on topic" do
    reply = Ai::Reply.new(RubyLLM::Message.new(role: :assistant, content: '{"off_topic": tr'))

    assert_raises(Ai::Reply::Malformed) { reply.off_topic? }
  end

  test "a reply that is JSON but not an object raises" do
    [ '"off_topic"', "[true]" ].each do |content|
      reply = Ai::Reply.new(RubyLLM::Message.new(role: :assistant, content: content))

      assert_raises(Ai::Reply::Malformed) { reply.parsed }
    end
  end

  test "search_results are only the pages the search returned, not a page a citation alone names" do
    message = Data.define(:citations, :web_sources).new(
      citations: [ RubyLLM::Citation.new(url: "https://www.jw.org/en/cited-only/", title: "Cited only", cited_text: "An excerpt.") ],
      web_sources: [ RubyLLM::WebSource.new(url: "https://www.jw.org/en/found/", title: "Found") ]
    )
    reply = Ai::Reply.new(message)

    assert_equal [ { url: "https://www.jw.org/en/found/", title: "Found" } ], reply.search_results
    assert_equal [ "https://www.jw.org/en/found/", "https://www.jw.org/en/cited-only/" ], reply.sources.pluck(:url)
  end
end
