require "test_helper"

class Ai::ModerationTest < ActiveSupport::TestCase
  test "flagged" do
    RubyLLM.stub(:moderate, moderation(flagged: true)) do
      assert Ai::Moderation.flagged?("something harmful")
    end
  end

  test "not flagged" do
    RubyLLM.stub(:moderate, ->(text) { moderation(flagged: text != "How can we pray as a family?") }) do
      assert_not Ai::Moderation.flagged?("How can we pray as a family?")
    end
  end

  private
    def moderation(flagged:)
      result = RubyLLM::Moderation::Result.new(flagged: flagged, categories: [], category_scores: {})
      RubyLLM::Moderation.new(id: "modr-test", model: "omni-moderation-latest", results: [ result ])
    end
end
