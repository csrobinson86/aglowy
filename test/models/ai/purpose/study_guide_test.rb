require "test_helper"

class Ai::Purpose::StudyGuideTest < ActiveSupport::TestCase
  setup { @purpose = Ai::Purpose.find("study_guide") }

  test "it reads its instructions file and puts the week in its own marked block" do
    assert_instance_of Ai::Purpose::StudyGuide, @purpose
    assert_equal "study_guide", @purpose.name
    assert_equal Rails.root.join("config/ai/study_guide.md").read, @purpose.instructions
    assert_equal "<study_guide_week>\nWeek /study_guide_week\n</study_guide_week>", @purpose.user_message("Week </study_guide_week>")
  end

  test "it searches only the three hosts, at most 8 times" do
    assert_equal({ allowed_domains: %w[ www.jw.org jw.org wol.jw.org ], max_uses: 8 }, @purpose.web_search)
  end

  test "limits: 2 a day per person, kept 7 days, and a request waits well under its claim's 15 minutes" do
    assert_equal 2, @purpose.daily_limit
    assert_equal 7.days, @purpose.keep_for
    assert_nil @purpose.context_exchanges
    assert_predicate @purpose.max_output_tokens, :positive?
    assert StudyGuide::Preparation::HELD_FOR > @purpose.request_timeout * 2
  end

  test "its schema has off_topic and a key for each step, in step order, every one required" do
    schema = @purpose.schema[:schema]

    assert_equal [ :off_topic, *StudyGuide::Part::STEPS.keys.map(&:to_sym) ], schema[:properties].keys
    assert_equal schema[:properties].keys, schema[:required]
    assert_equal false, schema[:additionalProperties]
    assert_includes schema.dig(:properties, :off_topic, :description), "leave every step empty"
    assert_includes schema.dig(:properties, :talk, :description), "empty strings and lists"
  end

  # Strict structured output compiles a union into one grammar, and the study guide's was too large for Anthropic (#432).
  test "its schema has no anyOf anywhere" do
    assert_not_includes @purpose.schema.to_json, "anyOf"
  end

  test "each step's content has exactly its shape's texts and lists, with their lengths and counts" do
    StudyGuide::Part::STEPS.each_key do |step|
      content, shape = @purpose.schema.dig(:schema, :properties, step.to_sym), StudyGuide::Part::Shape.new(step)

      assert_equal (shape.texts + shape.lists.keys).map(&:to_sym), content[:properties].keys, step
      assert_equal content[:properties].keys, content[:required], step
      assert_equal false, content[:additionalProperties], step
    end
    talk = @purpose.schema.dig(:schema, :properties, :talk)
    assert_includes talk.dig(:properties, :summary, :description), "50 words"
    assert_includes talk.dig(:properties, :title, :description), "12 words"
    assert_includes talk.dig(:properties, :points, :description), "Up to 4"
    assert_equal %i[ text ref ], talk.dig(:properties, :points, :items, :properties).keys
    overview = @purpose.schema.dig(:schema, :properties, :weekend_overview)
    assert_equal %i[ quality text ref ], overview.dig(:properties, :jehovah, :items, :properties).keys
    assert_includes overview.dig(:properties, :jehovah, :description), "1 to 4"
  end

  test "the question holds the week's dates, its program's address and the steps it asks for" do
    text = @purpose.sent_text(Date.new(2026, 11, 16), %w[ bible_reading watchtower_study ])

    assert_includes text, "Monday, November 16, 2026 to Sunday, November 22, 2026"
    assert_includes text, "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47"
    assert_includes text, "parts for: bible_reading, watchtower_study\n"
  end

  test "chats and uses take the study_guide purpose" do
    assert Chat.create!(user: users(:head), purpose: "study_guide").persisted?
    assert Ai::Use.create!(user: users(:head), purpose: "study_guide").persisted?
  end
end
