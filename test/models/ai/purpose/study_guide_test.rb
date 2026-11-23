require "test_helper"

class Ai::Purpose::StudyGuideTest < ActiveSupport::TestCase
  setup { @purpose = Ai::Purpose.find("study_guide") }

  test "it reads its instructions file and puts the week in its own marked block" do
    assert_instance_of Ai::Purpose::StudyGuide, @purpose
    assert_equal "study_guide", @purpose.name
    assert_equal Rails.root.join("config/ai/study_guide.md").read, @purpose.instructions
    assert_equal "<study_guide_week>\nWeek /study_guide_week\n</study_guide_week>", @purpose.user_message("Week </study_guide_week>")
  end

  test "it searches only the three hosts, at most 4 times a request" do
    assert_equal({ allowed_domains: %w[ www.jw.org jw.org wol.jw.org ], max_uses: 4 }, @purpose.web_search)
    assert_equal 4, @purpose.max_searches
  end

  test "limits: 6 a day per person, kept 7 days, and a request waits well under its claim's 15 minutes" do
    assert_equal 6, @purpose.daily_limit
    assert_equal 7.days, @purpose.keep_for
    assert_nil @purpose.context_exchanges
    assert_predicate @purpose.max_output_tokens, :positive?
    assert StudyGuide::Preparation::HELD_FOR > @purpose.request_timeout * 2
  end

  # All nine steps in one schema compiled into a grammar Anthropic rejected as too large, and so did midweek's seven (#432).
  test "the three groups cover every step once, in step order" do
    assert_equal %w[ midweek_opening midweek_ministry weekend ], Ai::Purpose::StudyGuide::GROUPS.keys
    assert_equal StudyGuide::Part::STEPS.keys, Ai::Purpose::StudyGuide::GROUPS.values.flatten
  end

  test "a group's schema has off_topic and exactly its steps, every one required, and no anyOf" do
    Ai::Purpose::StudyGuide::GROUPS.each_value do |steps|
      schema = @purpose.schema(steps)

      assert_equal "study_guide", schema[:name]
      assert_equal [ :off_topic, *steps.map(&:to_sym) ], schema.dig(:schema, :properties).keys
      assert_equal schema.dig(:schema, :properties).keys, schema.dig(:schema, :required)
      assert_equal false, schema.dig(:schema, :additionalProperties)
      assert_not_includes schema.to_json, "anyOf"
    end
  end

  test "a schema for one step has that step alone" do
    schema = @purpose.schema(%w[ watchtower_study ])[:schema]

    assert_equal %i[ off_topic watchtower_study ], schema[:properties].keys
    assert_includes schema.dig(:properties, :off_topic, :description), "leave every step empty"
    assert_includes schema.dig(:properties, :watchtower_study, :description), "empty strings and lists"
  end

  test "each step's content has exactly its shape's texts and lists, with their lengths and counts" do
    schema = @purpose.schema(StudyGuide::Part::STEPS.keys)[:schema]
    StudyGuide::Part::STEPS.each_key do |step|
      content, shape = schema.dig(:properties, step.to_sym), StudyGuide::Part::Shape.new(step)

      assert_equal (shape.texts + shape.lists.keys).map(&:to_sym), content[:properties].keys, step
      assert_equal content[:properties].keys, content[:required], step
      assert_equal false, content[:additionalProperties], step
    end
    talk = schema.dig(:properties, :talk)
    assert_includes talk.dig(:properties, :summary, :description), "50 words"
    assert_includes talk.dig(:properties, :title, :description), "12 words"
    assert_includes talk.dig(:properties, :points, :description), "Up to 4"
    assert_equal %i[ text ref ], talk.dig(:properties, :points, :items, :properties).keys
    overview = schema.dig(:properties, :weekend_overview)
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
