require "test_helper"

# One week's Get ready cards for a household (docs/design/meeting-prep.md, PrepWeek).
class PrepWeekTest < ActiveSupport::TestCase
  setup { @week = prep_weeks(:home_nov_9) }

  test "cards_for lists a meeting's cards in the helper's step order" do
    prep_card(@week, "watchtower_study")
    prep_card(@week, "congregation_bible_study")
    prep_card(@week, "living")

    assert_equal %w[ talk bible_reading living congregation_bible_study ], @week.reload.cards_for("midweek").map(&:step)
    assert_equal %w[ watchtower_study ], @week.cards_for("weekend").map(&:step)
    helper_order = MeetingNote::HelperSteps.for("midweek").map(&:key) & PrepWeek::Card::STEPS.keys
    assert_equal helper_order, @week.cards_for("midweek").map(&:step)
  end

  test "prep_week_for reads the week with its cards and sources, or nil" do
    assert_equal @week, households(:home).prep_week_for(Date.new(2026, 11, 9))
    assert_nil households(:home).prep_week_for(Date.new(2026, 11, 16))
  end

  test "deleting the week deletes its cards and sources, and deleting the household deletes its weeks" do
    source = @week.sources.create!(position: 1, title: "Workbook", url: "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/46")
    card = prep_week_cards(:home_nov_9_talk)
    @week.destroy!

    assert_not PrepWeek::Card.exists?(card.id)
    assert_not PrepWeek::Source.exists?(source.id)

    week = PrepWeek.create!(household: households(:home), week_of: Date.new(2026, 11, 16))
    households(:home).destroy!
    assert_not PrepWeek.exists?(week.id)
  end

  test "deleting its chat keeps the week" do
    chat = Chat.create!(user: users(:head), household: households(:home), purpose: "meeting_prep")
    @week.update!(chat:)
    chat.destroy!

    assert_nil @week.reload.chat
  end

  test "database: a second week for the same household and Monday" do
    assert_raises(ActiveRecord::RecordNotUnique) { PrepWeek.insert!({ household_id: @week.household_id, week_of: @week.week_of }) }
  end

  test "database: a source that isn't https" do
    assert_raises(ActiveRecord::CheckViolation) { PrepWeek::Source.insert!({ prep_week_id: @week.id, position: 1, title: "A", url: "http://wol.jw.org/" }) }
  end

  test "database: two sources in one position" do
    @week.sources.create!(position: 1, title: "A", url: "https://wol.jw.org/a")

    assert_raises(ActiveRecord::RecordNotUnique) { PrepWeek::Source.insert!({ prep_week_id: @week.id, position: 1, title: "B", url: "https://wol.jw.org/b" }) }
  end
end
