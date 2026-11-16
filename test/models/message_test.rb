require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "content is encrypted at rest" do
    message = messages(:head_draft_question)
    raw = Message.connection.select_value(Message.where(id: message.id).select(:content).to_sql)

    assert_equal "How can we help our children face peer pressure?", message.content
    assert_not_includes raw, "peer pressure"
  end
end
