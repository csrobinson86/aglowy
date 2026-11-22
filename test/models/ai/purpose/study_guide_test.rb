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

  test "its schema has off_topic and a list of parts, each a step with its own fields" do
    schema = @purpose.schema[:schema]

    assert_equal %i[ off_topic parts ], schema[:properties].keys
    assert_equal schema[:properties].keys, schema[:required]
    shapes = schema.dig(:properties, :parts, :items, :anyOf)
    assert_equal StudyGuide::Part::STEPS.keys.sort, shapes.flat_map { it.dig(:properties, :step, :enum) }.sort
    talk = shapes.find { it.dig(:properties, :step, :enum) == %w[ talk ] }.dig(:properties, :content)
    assert_equal %i[ title summary points jehovah ], talk[:properties].keys
    assert_equal talk[:properties].keys, talk[:required]
    assert_includes talk.dig(:properties, :summary, :description), "50 words"
    assert_includes talk.dig(:properties, :title, :description), "12 words"
    assert_includes talk.dig(:properties, :points, :description), "Up to 4"
    assert_equal %i[ text ref ], talk.dig(:properties, :points, :items, :properties).keys
    overview = shapes.find { it.dig(:properties, :step, :enum).include?("midweek_overview") }.dig(:properties, :content)
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
