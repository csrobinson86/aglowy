require "test_helper"

class DailyBrief::FocusAreaTest < ActiveSupport::TestCase
  setup do
    @plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
  end

  test "name and gives are required and limited" do
    area = new_area(name: " ", gives: "")

    assert_not area.valid?
    assert_equal [ "can't be blank" ], area.errors[:name]
    assert_equal [ "can't be blank" ], area.errors[:gives]

    area = new_area(name: "a" * 61, gives: "b" * 201)
    assert_not area.valid?
    assert_equal [ "is too long (maximum is 60 characters)" ], area.errors[:name]
    assert_equal [ "is too long (maximum is 200 characters)" ], area.errors[:gives]

    assert new_area(name: "a" * 60, gives: "b" * 200).valid?
  end

  test "scriptures that don't parse are refused" do
    area = new_area(scriptures: "Ephesians 5:25, 28; Proverbs 5:18")

    assert_not area.valid?
    assert_equal [ "has a reference that isn't a Bible verse: Ephesians 5:25, 28" ], area.errors[:scriptures]
    assert_not new_area(scriptures: "Proverbs 4:23; Hezekiah 3:1").valid?
    assert_not new_area(scriptures: "Proverbs 4:23; " * 9).valid?, "more than 120 characters"

    assert new_area(scriptures: " Proverbs 4:23; Colossians 3:23 ").valid?
    assert_nil new_area(scriptures: " ").scriptures
  end

  test "a seventh is refused" do
    new_area.save!

    seventh = new_area(name: "Guard your heart")
    assert_not seventh.save
    assert_equal [ "You can have six focus areas at most" ], seventh.errors[:base]
    assert @plan.focus_areas.first.update(name: "As a husband today"), "a sixth can still be edited"
  end

  test "the kind is one of the three" do
    assert_not new_area(kind: "prayer").valid?
  end

  test "the database refuses a second quality" do
    assert_raises(ActiveRecord::RecordNotUnique) { insert_area(kind: "quality") }
  end

  test "the database refuses a second appreciation" do
    assert_raises(ActiveRecord::RecordNotUnique) { insert_area(kind: "appreciation") }
  end

  test "the database refuses a kind that isn't one of the three" do
    assert_raises(ActiveRecord::CheckViolation) { insert_area(kind: "prayer") }
  end

  test "the database refuses scriptures longer than 120 characters" do
    assert_raises(ActiveRecord::CheckViolation) { insert_area(scriptures: "a" * 121) }
  end

  test "name and gives are encrypted" do
    area = new_area(name: "At work", gives: "One honest thing at the office")
    area.save!

    raw = DailyBrief::FocusArea.connection.select_one(DailyBrief::FocusArea.where(id: area.id).select(:name, :gives).to_sql)
    assert_not_includes raw["name"], "At work"
    assert_not_includes raw["gives"], "honest"
    assert_equal "At work", area.reload.name
  end

  test "the scriptures as references, for their links" do
    area = new_area(scriptures: "Proverbs 4:23; Colossians 3:23")

    assert_equal [ "Proverbs 4:23", "Colossians 3:23" ], area.scripture_references.map(&:to_s)
    assert_empty new_area.scripture_references
  end

  test "the library holds the eleven ready-made focus areas, each of whose scriptures parse" do
    library = DailyBrief::FocusArea::Library.all

    assert_equal [ "As a husband", "As a father", "As a wife", "As a mother", "Reaching out", "In the ministry", "In the congregation",
                   "At work", "Guard your heart", "Qualities to focus on", "Growing appreciation for Jehovah" ], library.map(&:name)
    library.each do |entry|
      assert new_area(kind: entry.kind, name: entry.name, gives: entry.gives, scriptures: entry.scriptures).valid?, "#{entry.name} is valid"
    end
    assert_equal "quality", DailyBrief::FocusArea::Library.find("qualities").kind
  end

  test "destroying one removes its key from every day's topics" do
    reaching_out = @plan.focus_areas.find_by!(name: "Reaching out")
    husband = @plan.focus_areas.find_by!(name: "As a husband")
    assert_equal 7, @plan.days.count { it.topics.key?(reaching_out.id) }

    reaching_out.destroy!

    @plan.days.reload.each do |day|
      assert_not day.topics.key?(reaching_out.id), "#{day.short_name} still has its topic"
    end
    assert_equal "Love my wife as my own body", @plan.days.find_by!(wday: 1).topic_for(husband), "other focus areas keep theirs"
  end

  test "position is the next free one on create" do
    area = @plan.focus_areas.create!(kind: "role", name: "At work", gives: "One honest thing.")
    assert_equal 5, area.position

    @plan.focus_areas.find_by!(position: 2).destroy!
    assert_equal 6, @plan.focus_areas.create!(kind: "role", name: "In the ministry", gives: "One way.").position

    basics = DailyBrief::Plan.start(users(:spouse), starter: "basics")
    basics.focus_areas.delete_all
    assert_equal 0, basics.focus_areas.create!(kind: "role", name: "At work", gives: "One honest thing.").position
  end

  test "a second quality or appreciation is refused with a reason" do
    quality = new_area(kind: "quality", name: "Qualities")

    assert_not quality.valid?
    assert_equal [ "You already have a quality focus area" ], quality.errors[:kind]
    assert_not new_area(kind: "appreciation").valid?
    assert @plan.focus_areas.find_by!(kind: "quality").valid?, "the one it has is still valid"
  end

  private
    def new_area(**attributes)
      @plan.focus_areas.new(position: 6, kind: "role", name: "At work", gives: "One way to show honesty at work today.", **attributes)
    end

    def insert_area(**attributes)
      DailyBrief::FocusArea.insert!({ plan_id: @plan.id, position: 6, kind: "role", name: "x", gives: "x", **attributes })
    end
end
