require "test_helper"

class DailyBriefsHelperTest < ActionView::TestCase
  test "verses_label names one verse or several, and says look for when the reference names none" do
    assert_equal "Verse 22", verses_label("Matthew 16:22")
    assert_equal "Verses 21-23", verses_label("Matthew 16:21-23")
    assert_equal "Verses 8, 9", verses_label("Psalm 37:8, 9")
    assert_equal "Look for", verses_label("Matthew 16")
    assert_equal "Look for", verses_label("not a reference")
  end

  test "evening_title follows the count" do
    assert_equal "Four questions to end the day", evening_title(4)
    assert_equal "Three questions to end the day", evening_title(3)
    assert_equal "One question to end the day", evening_title(1)
  end

  test "evening_from names the section by its name in the brief, or keeps the AI's own word" do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
    travel_to(Time.utc(2026, 11, 14, 12)) { DailyBrief::Plan.start(users(:head), starter: "husband_and_father") }
    brief = DailyBrief.for(users(:head), on: Date.new(2026, 11, 17))
    writing = DailyBrief::Writing.new(result: { "quality" => { "name" => "Patience" } })

    assert_equal "Daily text", evening_from(brief, writing, "daily_text")
    assert_equal "Bible reading", evening_from(brief, writing, "reading")
    assert_equal "Patience", evening_from(brief, writing, "quality")
    assert_equal brief.appreciation_area.name, evening_from(brief, writing, "appreciation")
    assert_equal "Your focus", evening_from(brief, writing, "focus")
    assert_equal "Imitate their faith", evening_from(brief, writing, "faith")
    assert_equal "Looking back honestly", evening_from(brief, writing, "Looking back honestly")
    assert_nil evening_from(brief, writing, "")
  end
end
