require "test_helper"

class FilterParametersTest < ActionDispatch::IntegrationTest
  setup do
    @filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
  end

  test "AI prompts, message content and draft outlines are filtered from the logs" do
    filtered = @filter.filter("draft" => { "prompt" => "Our son is struggling", "outline" => "{}" }, "content" => "Mine", "length_minutes" => "30")

    assert_equal({ "prompt" => "[FILTERED]", "outline" => "[FILTERED]" }, filtered["draft"])
    assert_equal "[FILTERED]", filtered["content"]
    assert_equal "30", filtered["length_minutes"]
  end

  # Rails filters a note's encrypted rich text only as encrypted_rich_text.body, not as the form's personal_note[body].
  test "a note's body is filtered and its color isn't" do
    filtered = @filter.filter("personal_note" => { "body" => "<p>Pray for Dad</p>", "color" => "blue" })

    assert_equal({ "body" => "[FILTERED]", "color" => "blue" }, filtered["personal_note"])
  end

  # The change form's param key isn't card's, so Rails' filters for PrepWeek::Card's encrypted attributes miss it.
  # Every field but quality, so a new one fails here until it is filtered.
  test "a Get ready card change's text fields are filtered and its quality isn't" do
    texts = (PrepWeek::Card::Change.attribute_names - [ "quality" ]).index_with { "Private words" }

    filtered = @filter.filter("prep_week_card_change" => texts.merge("quality" => "kind"))

    assert_equal texts.transform_values { "[FILTERED]" }.merge("quality" => "kind"), filtered["prep_week_card_change"]
  end

  test "sign-in names are filtered" do
    filtered = @filter.filter("identity" => { "login" => "eli.rivera", "username" => "eli.rivera", "remember_me" => "1" })

    assert_equal({ "login" => "[FILTERED]", "username" => "[FILTERED]", "remember_me" => "1" }, filtered["identity"])
  end
end
