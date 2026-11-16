require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "a chat needs a user" do
    chat = Chat.new(household: households(:home), purpose: "family_study_draft")

    assert_not chat.valid?
    assert_equal [ "must exist" ], chat.errors[:user]
  end

  test "a chat needs a known purpose" do
    chat = Chat.new(user: users(:head), purpose: "chatbot")

    assert_not chat.valid?
    assert_equal [ "is not included in the list" ], chat.errors[:purpose]
  end

  test "the database refuses an unknown purpose" do
    assert_raises(ActiveRecord::StatementInvalid) { chats(:head_draft).update_column(:purpose, "chatbot") }
  end

  test "a chat outside a household has no household" do
    chat = Chat.create!(user: users(:head), purpose: "family_study_draft")

    assert_nil chat.household
    assert_equal ruby_llm_models(:test_model), chat.model
  end

  test "destroying a chat destroys its messages and the usage it recorded" do
    chat = chats(:head_draft)
    RubyLLM::ActiveRecord::Usage.create!(chat: chat, operation: "chat", provider: "anthropic", model: "claude-sonnet-5-5", status: "succeeded")

    assert_difference [ -> { Message.count }, -> { RubyLLM::ActiveRecord::Usage.count } ], -1 do
      chat.destroy
    end
  end
end
