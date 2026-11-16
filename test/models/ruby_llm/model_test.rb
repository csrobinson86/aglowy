require "test_helper"

class RubyLLM::ActiveRecord::ModelTest < ActiveSupport::TestCase
  test "the model registry is saved with UUIDv7 ids, and a model already saved keeps its id" do
    saved = ruby_llm_models(:test_model)
    added = RubyLLM::ActiveRecord::Model.new(model_id: "claude-haiku-5-5", name: "Claude Haiku 5.5", provider: "anthropic")
    registry = RubyLLM::Models.new(RubyLLM::ActiveRecord::Model.all.map(&:to_llm) << added.to_llm)

    RubyLLM::ActiveRecord::Model.save_to_database(registry)

    assert_equal 7, RubyLLM::ActiveRecord::Model.find_by!(model_id: "claude-haiku-5-5").id[14].to_i
    assert_equal saved.id, RubyLLM::ActiveRecord::Model.find_by!(provider: saved.provider, model_id: saved.model_id).id
  end
end
