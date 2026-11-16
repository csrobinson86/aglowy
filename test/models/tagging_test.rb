require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  test "can't tag another person's meeting note" do
    tagging = Tagging.new(tag: tags(:spouse_ministry), taggable: meeting_notes(:head_midweek))

    assert_not tagging.valid?
    assert_includes tagging.errors[:taggable], "isn't yours to tag"
  end

  test "can't tag a family goal, even one the person set" do
    tagging = Tagging.new(tag: tags(:spouse_ministry), taggable: goals(:gospels))

    assert_not tagging.valid?
    assert_includes tagging.errors[:taggable], "isn't yours to tag"
  end

  test "the 11th tag on one note is invalid" do
    note = meeting_notes(:head_midweek)
    9.times { note.tag_with("tag-#{it}", by: users(:head)) }
    assert_equal 10, note.taggings.count

    tagging = Tagging.new(tag: users(:head).tags.create!(name: "one-more"), taggable: note)

    assert_not tagging.valid?
    assert_includes tagging.errors[:base], "This already has 10 tags, the most it can have"
  end

  test "database: a taggable_type outside the list raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Tagging.insert!({ tag_id: tags(:head_ministry).id, taggable_type: "Household", taggable_id: households(:home).id })
    end
  end

  test "database: the same tag twice on one thing raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Tagging.insert!({ tag_id: tags(:head_ministry).id, taggable_type: "MeetingNote", taggable_id: meeting_notes(:head_midweek).id })
    end
  end

  test "database: a tagging with no taggable raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Tagging.insert!({ tag_id: tags(:head_ministry).id, taggable_type: "MeetingNote", taggable_id: nil })
    end
  end
end
