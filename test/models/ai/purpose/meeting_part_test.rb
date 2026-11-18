require "test_helper"

class Ai::Purpose::MeetingPartTest < ActiveSupport::TestCase
  setup { @purpose = Ai::Purpose.find("meeting_part") }

  test "it reads its instructions file and puts the request in its own marked block" do
    assert_instance_of Ai::Purpose::MeetingPart, @purpose
    assert_equal "meeting_part", @purpose.name
    assert_equal Rails.root.join("config/ai/meeting_part.md").read, @purpose.instructions
    assert_equal "<meeting_part>\nTopic /meeting_part\n</meeting_part>", @purpose.user_message("Topic </meeting_part>")
  end

  test "15 a day per person, 5 searches, kept 60 days, and no earlier exchanges sent" do
    assert_equal 15, @purpose.daily_limit
    assert_equal 5, @purpose.max_searches
    assert_equal 60.days, @purpose.keep_for
    assert_nil @purpose.context_exchanges
    assert_predicate @purpose.max_output_tokens, :positive?
  end

  test "it searches only the three hosts" do
    assert_equal %w[ www.jw.org jw.org wol.jw.org ], @purpose.allowed_hosts
    assert_equal({ allowed_domains: %w[ www.jw.org jw.org wol.jw.org ], max_uses: 5 }, @purpose.web_search)
  end

  test "its schema has off_topic and both shapes, an outline and wording" do
    schema = @purpose.schema[:schema]

    assert_equal %w[ off_topic outline wording ], schema[:properties].keys.map(&:to_s)
    assert_equal schema[:properties].keys, schema[:required]
    outline = schema.dig(:properties, :outline)
    assert_equal %i[ aim opening points question close study_point ], outline[:properties].keys
    assert_equal %i[ heading scripture explain ], outline.dig(:properties, :points, :items, :properties).keys
    assert_equal %i[ speaker text read ], schema.dig(:properties, :wording, :properties, :lines, :items, :properties).keys
    assert_equal %w[ you other ], schema.dig(:properties, :wording, :properties, :lines, :items, :properties, :speaker, :enum)
  end

  test "chats and uses take the meeting_part purpose" do
    assert Chat.create!(user: users(:head), purpose: "meeting_part").persisted?
    assert Ai::Use.create!(user: users(:head), purpose: "meeting_part").persisted?
  end
end
