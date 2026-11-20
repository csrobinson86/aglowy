require "test_helper"

class Ai::Purpose::MeetingPrepTest < ActiveSupport::TestCase
  setup { @purpose = Ai::Purpose.find("meeting_prep") }

  test "it reads its instructions file and puts the week in its own marked block" do
    assert_instance_of Ai::Purpose::MeetingPrep, @purpose
    assert_equal "meeting_prep", @purpose.name
    assert_equal Rails.root.join("config/ai/meeting_prep.md").read, @purpose.instructions
    assert_equal "<meeting_prep_week>\nWeek /meeting_prep_week\n</meeting_prep_week>", @purpose.user_message("Week </meeting_prep_week>")
  end

  test "it searches only the three hosts" do
    assert_equal %w[ www.jw.org jw.org wol.jw.org ], @purpose.allowed_hosts
    assert_equal({ allowed_domains: %w[ www.jw.org jw.org wol.jw.org ], max_uses: 6 }, @purpose.web_search)
  end

  test "limits: 3 a day per household, 6 searches, kept 7 days, and a request waits well under its claim's 15 minutes" do
    assert_equal 3, @purpose.daily_limit
    assert_equal 6, @purpose.max_searches
    assert_equal 7.days, @purpose.keep_for
    assert_nil @purpose.context_exchanges
    assert_predicate @purpose.max_output_tokens, :positive?
    assert_equal 5.minutes, @purpose.request_timeout
    assert PrepWeek::Preparation::HELD_FOR > @purpose.request_timeout * 2
  end

  test "its schema has off_topic and a list of cards with the design's fields" do
    schema = @purpose.schema[:schema]

    assert_equal %i[ off_topic cards ], schema[:properties].keys
    assert_equal schema[:properties].keys, schema[:required]
    card = schema.dig(:properties, :cards, :items)
    assert_equal %i[ step about quality quality_line i_can reading story ], card[:properties].keys
    assert_equal card[:properties].keys, card[:required]
    assert_equal %w[ talk bible_reading living congregation_bible_study watchtower_study ], card.dig(:properties, :step, :enum)
    assert_equal PrepWeek::Card::QUALITIES.keys, card.dig(:properties, :quality, :enum)
    assert_includes card.dig(:properties, :about, :description), "20 words"
    %i[ quality_line i_can ].each { assert_includes card.dig(:properties, it, :description), "14 words" }
    assert_includes card.dig(:properties, :story, :description), "2 to 4 sentences"
  end

  test "the question holds the week's dates, its program's address and the steps it asks for" do
    text = @purpose.sent_text(Date.new(2026, 11, 16), %w[ bible_reading watchtower_study ])

    assert_includes text, "Monday, November 16, 2026 to Sunday, November 22, 2026"
    assert_includes text, "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47"
    assert_includes text, "cards for: bible_reading, watchtower_study\n"
  end

  test "chats and uses take the meeting_prep purpose" do
    assert Chat.create!(user: users(:head), household: households(:home), purpose: "meeting_prep").persisted?
    assert Ai::Use.create!(user: users(:head), purpose: "meeting_prep").persisted?
  end
end
