require "test_helper"

class DailyBrief::DayTest < ActiveSupport::TestCase
  setup do
    @plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    @day = @plan.days.find_by!(wday: 1)
    @husband = @plan.focus_areas.find_by!(position: 0)
  end

  test "reading, examples and each topic are limited, and a blank box means the brief chooses" do
    @day.assign_attributes(reading: "a" * 121, examples: "b" * 201, topics: { @husband.id => "c" * 121 })

    assert_not @day.valid?
    assert_equal [ "is too long (maximum is 120 characters)" ], @day.errors[:reading]
    assert_equal [ "is too long (maximum is 200 characters)" ], @day.errors[:examples]
    assert_equal [ "are 120 characters at most each" ], @day.errors[:topics]

    @day.assign_attributes(reading: " ", examples: "", topics: { @husband.id => " " })
    assert @day.valid?
    assert_nil @day.reading
    assert_nil @day.examples
    assert_nil @day.topic_for(@husband)
  end

  test "a topic for another plan's focus area, or for none, is refused" do
    theirs = DailyBrief::Plan.start(users(:spouse), starter: "wife_and_mother").focus_areas.first

    [ theirs.id, "not-a-focus-area" ].each do |key|
      @day.topics = { @husband.id => "Love my wife", key => "Theirs" }

      assert_not @day.valid?
      assert_equal [ "can only be for your own focus areas" ], @day.errors[:topics]
    end
  end

  test "revise saves the day, a blank box taking its topic off, or keeps it unsaved with the reasons" do
    father = @plan.focus_areas.find_by!(position: 1)

    assert @day.revise(reading: "Exodus", examples: "Moses", topics: { @husband.id => "", father.id => "Family worship" })
    @day.reload
    assert_equal [ "Exodus", "Moses", nil, "Family worship" ], [ @day.reading, @day.examples, @day.topic_for(@husband), @day.topic_for(father) ]

    assert_not @day.revise(reading: "a" * 121)
    assert_equal [ "is too long (maximum is 120 characters)" ], @day.errors[:reading]
    assert_equal "Exodus", @day.reload.reading
  end

  test "revise changes only the topics sent, so one the dialog didn't show is kept" do
    father = @plan.focus_areas.find_by!(position: 1)
    @day.update!(topics: { father.id => "Family worship" })

    assert @day.revise(topics: { @husband.id => "Listen first" })
    assert_equal({ father.id => "Family worship", @husband.id => "Listen first" }, @day.reload.topics)

    assert @day.revise(reading: "Exodus")
    assert_equal({ father.id => "Family worship", @husband.id => "Listen first" }, @day.reload.topics)
  end

  test "revise merges the topics sent with string keys too" do
    father = @plan.focus_areas.find_by!(position: 1)
    @day.update!(topics: { father.id => "Family worship" })

    assert @day.revise("topics" => { @husband.id => "Listen first" })
    assert_equal({ father.id => "Family worship", @husband.id => "Listen first" }, @day.reload.topics)
  end

  test "the name of its day, from Sunday" do
    assert_equal "Mon", @day.short_name
    assert_equal "Monday", @day.name
    assert_equal "Sun", @plan.days.first.short_name
  end

  test "reading, examples and topics are encrypted" do
    raw = DailyBrief::Day.connection.select_one(DailyBrief::Day.where(id: @day.id).select(:reading, :examples, :topics).to_sql)

    assert_not_includes raw["reading"], "Genesis"
    assert_not_includes raw["examples"], "Noah"
    assert_not_includes raw["topics"], "Love my wife"
    assert_equal "Love my wife as my own body", @day.reload.topic_for(@husband)
  end

  test "the database refuses a second row for a weekday" do
    assert_raises(ActiveRecord::RecordNotUnique) { DailyBrief::Day.insert!({ plan_id: @plan.id, wday: 1 }) }
  end

  test "the database refuses a weekday outside 0 to 6" do
    assert_raises(ActiveRecord::CheckViolation) { DailyBrief::Day.insert!({ plan_id: @plan.id, wday: 7 }) }
  end
end
