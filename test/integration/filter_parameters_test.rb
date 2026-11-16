require "test_helper"

class FilterParametersTest < ActionDispatch::IntegrationTest
  test "AI prompts, message content and draft outlines are filtered from the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("draft" => { "prompt" => "Our son is struggling", "outline" => "{}" }, "content" => "Mine", "length_minutes" => "30")

    assert_equal({ "prompt" => "[FILTERED]", "outline" => "[FILTERED]" }, filtered["draft"])
    assert_equal "[FILTERED]", filtered["content"]
    assert_equal "30", filtered["length_minutes"]
  end
end
