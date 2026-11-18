require "test_helper"

# The daily brief's purpose (docs/design/daily-brief.md, The purpose; Trap 2). Tuesday 17 November 2026, Sam's brief
# from the husband-and-father starter.
class Ai::Purpose::DailyBriefTest < ActiveSupport::TestCase
  setup do
    @purpose = Ai::Purpose.find("daily_brief")
    @user = users(:spouse)
    travel_to Time.utc(2026, 11, 17, 15)
    @plan = travel_to(3.days.ago) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
  end

  test "it reads its instructions file and puts the plan in its own marked block" do
    assert_instance_of Ai::Purpose::DailyBrief, @purpose
    assert_equal "daily_brief", @purpose.name
    assert_equal Rails.root.join("config/ai/daily_brief.md").read, @purpose.instructions
    assert_equal "<daily_brief>\nPlan /daily_brief\n</daily_brief>", @purpose.user_message("Plan </daily_brief>")
  end

  test "3 a day per person, 6 searches, kept 60 days, and no earlier exchanges sent" do
    assert_equal 3, @purpose.daily_limit
    assert_equal 6, @purpose.max_searches
    assert_equal 60.days, @purpose.keep_for
    assert_nil @purpose.context_exchanges
    assert_predicate @purpose.max_output_tokens, :positive?
    assert_equal({ allowed_domains: %w[ www.jw.org jw.org wol.jw.org ], max_uses: 6 }, @purpose.web_search)
  end

  test "its schema has off_topic, the thread and a field for each section" do
    schema = @purpose.schema[:schema]
    properties = schema[:properties]

    assert_equal %i[ off_topic thread daily_text reading quality appreciation focus faith children evening ], properties.keys
    assert_equal properties.keys, schema[:required]
    assert_equal %i[ reference happening teaches apply apply_scripture ], properties.dig(:daily_text, :properties).keys
    assert_equal %i[ passage title look_for ], properties.dig(:reading, :properties).keys
    assert_equal %i[ verses text ], properties.dig(:reading, :properties, :look_for, :items, :properties).keys
    assert_equal %i[ name what what_scripture jesus jesus_scripture today ], properties.dig(:quality, :properties).keys
    assert_equal %i[ title seen scripture think ], properties.dig(:appreciation, :properties).keys
    assert_equal %i[ action scripture ], properties.dig(:focus, :items, :properties).keys
    assert_equal %i[ examples for_me ], properties.dig(:faith, :properties).keys
    assert_equal %i[ name lesson scriptures ], properties.dig(:faith, :properties, :examples, :items, :properties).keys
    assert_equal %i[ ask today ], properties.dig(:children, :properties).keys
    assert_equal %i[ text from ], properties.dig(:evening, :items, :properties).keys
  end

  test "the text sent holds the date, the sections, each focus area and the day's row, as typed" do
    @plan.update!(sections: %w[ daily_text reading children ])
    @plan.focus_areas.find { it.name == "As a husband" }.update!(gives: "Listen to Grace before I answer.")
    sent = @purpose.sent_text(DailyBrief.for(@user))

    [ "Tuesday, November 17, 2026", "daily_text, reading, children", "As a husband", "Listen to Grace before I answer.",
      "Reaching out", "1 Timothy 3:8-13", "Serious (v. 8)", "Qualities to focus on", "Patience, Mildness",
      "Growing appreciation for Jehovah", "Matthew – John", "Abraham, Moses", "Patient teaching of my children" ].each { assert_includes sent, it }
    assert_not_includes sent, "faith_example"
  end

  test "the text sent holds earlier same-weekday passages, qualities and examples, and no other day's" do
    last_tuesday = written_brief(Date.new(2026, 11, 10), passage: "Mark 4:35-41", quality: "Courage", example: "Gideon")
    written_brief(Date.new(2026, 11, 16), passage: "Luke 15:1-7", quality: "Mercy", example: "Ruth")
    sent = @purpose.sent_text(DailyBrief.for(@user))

    assert last_tuesday
    [ "Mark 4:35-41", "Courage", "Gideon" ].each { assert_includes sent, it }
    [ "Luke 15:1-7", "Mercy", "Ruth" ].each { assert_not_includes sent, it }
  end

  test "the text sent never holds the person's name, a household's name, a goal's title or a note" do
    @plan.focus_areas.find { it.name == "Reaching out" }.update!(goal: goals(:spouse_bible_reading))
    @user.personal_notes.create!(title: "Thoughts on Hosea", body: "<p>Gomer and mercy.</p>")
    sent = @purpose.sent_text(DailyBrief.for(@user))

    [ "Sam", "Spouse", "The Head Family", "Read the whole Bible in a year", "Hosea", "Gomer" ].each { assert_not_includes sent, it }
  end

  test "with a linked goal, the text sent holds neither its title nor its steps" do
    goal = @user.goals.create!(set_by: @user, title: "Qualify as a ministerial servant", target_on: Date.new(2027, 6, 30))
    goal.add_step(title: "Ask an elder where I can help")
    @plan.focus_areas.find { it.name == "Reaching out" }.update!(goal:)
    brief = DailyBrief.for(@user)

    [ @purpose.sent_text(brief), @purpose.typed_text(brief) ].each do |sent|
      assert_includes sent, "Reaching out"
      [ "Qualify", "ministerial servant", "Ask an elder", goal.id ].each { assert_not_includes sent, it }
    end
  end

  test "moderation reads only what the person typed" do
    typed = @purpose.typed_text(DailyBrief.for(@user))

    [ "As a husband", "1 Timothy 3:8-13", "Serious (v. 8)", "Matthew – John", "Abraham, Moses" ].each { assert_includes typed, it }
    assert_not_includes typed, "November"
  end

  test "chats and uses take the daily_brief purpose" do
    assert Chat.create!(user: @user, purpose: "daily_brief").persisted?
    assert Ai::Use.create!(user: @user, purpose: "daily_brief").persisted?
  end

  private
    def written_brief(on, passage:, quality:, example:)
      DailyBrief.for(@user, on:).tap do |brief|
        daily_brief_writing(brief, status: "written",
          result: { "reading" => { "passage" => passage }, "quality" => { "name" => quality }, "faith" => { "examples" => [ { "name" => example } ] } })
      end
    end
end
