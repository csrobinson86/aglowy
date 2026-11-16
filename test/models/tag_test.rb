require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "Talk Prep, #talk_prep and a padded talk-prep all normalize to talk-prep" do
    assert_equal %w[ talk-prep ] * 3, [ "Talk Prep", "#talk_prep", "  talk-prep " ].map { Tag.normalize(it) }
  end

  test "a nonbreaking space isn't whitespace to Ruby, so it's dropped, not made a hyphen" do
    assert_equal "talkprep", Tag.normalize("talk\u00A0prep")
  end

  test "a name that normalizes to nothing is invalid" do
    assert_equal "", Tag.normalize("###")

    assert_no_difference -> { Tag.count } do
      assert_raises(ActiveRecord::RecordInvalid) { users(:head).tags.find_or_create_by_name!("###") }
    end
  end

  test "the 201st tag is invalid, but finding one the person already has still works" do
    Tag.insert_all(Array.new(199) { |n| { user_id: users(:head).id, name: "tag-#{n}" } })

    tag = users(:head).tags.build(name: "one-more")
    assert_not tag.valid?
    assert_includes tag.errors[:base], "You already have 200 tags, the most you can have"
    assert_equal tags(:head_ministry), users(:head).tags.find_or_create_by_name!("Ministry")
  end

  test "at the limit, a create that races past the lookup gets the tag the other request made" do
    Tag.insert_all(Array.new(199) { |n| { user_id: users(:head).id, name: "tag-#{n}" } })

    assert_equal tags(:head_ministry), users(:head).tags.create_or_find_by!(name: "ministry")
  end

  test "rename normalizes the new name and keeps the tag on everything it was on" do
    tag = tags(:head_ministry)

    assert tag.rename("#Field Service")
    assert_equal "field-service", tag.reload.name
    assert_equal [ tag ], meeting_notes(:head_midweek).tags.to_a
  end

  test "rename to a name the person already has fails; another person's same name doesn't count" do
    users(:head).tags.create!(name: "prayer")
    users(:spouse).tags.create!(name: "service")
    tag = tags(:head_ministry)

    assert_not tag.rename("Prayer")
    assert_equal [ "You already have #prayer." ], tag.errors.full_messages
    assert_equal "ministry", tag.reload.name
    assert tag.rename("service")
  end

  test "rename to a name that normalizes to nothing fails" do
    assert_not tags(:head_ministry).rename("###")
    assert_equal "ministry", tags(:head_ministry).reload.name
  end

  test "meeting notes and goals carrying it, newest first; no personal studies before PSTUDY-01" do
    tag = tags(:head_ministry)
    meeting_notes(:head_weekend).tag_with("ministry", by: users(:head))
    older = users(:head).goals.create!(title: "Read the Psalms", target_on: Date.new(2027, 2, 28), set_by: users(:head))
    newer = users(:head).goals.create!(title: "Start a Bible study", target_on: Date.new(2027, 1, 31), set_by: users(:head))
    [ older, newer ].each { it.tag_with("ministry", by: users(:head)) }

    assert_equal [ meeting_notes(:head_weekend), meeting_notes(:head_midweek) ], tag.meeting_notes.to_a
    assert_equal [ newer, older ], tag.goals.to_a
    assert_empty tag.personal_studies
  end

  test "database: a name that isn't normalized raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Tag.insert!({ user_id: users(:head).id, name: "Talk Prep" })
    end
  end

  test "database: a duplicate name for the same person raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Tag.insert!({ user_id: users(:head).id, name: "ministry" })
    end
  end

  test "database: a tag with no person raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Tag.insert!({ user_id: nil, name: "ministry" })
    end
  end
end
