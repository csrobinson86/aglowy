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
end
