require "test_helper"

class PersonalNoteTest < ActiveSupport::TestCase
  test "title is 1 to 120 characters" do
    note = users(:head).personal_notes.new

    [ "", "   ", "x" * 121 ].each do |title|
      note.title = title
      assert_not note.valid?, "expected #{title.inspect} to be refused"
      assert note.errors[:title].any?
    end

    [ "x", "x" * 120 ].each do |title|
      note.title = title
      assert note.valid?, "expected a #{title.length}-character title to be valid"
    end
  end

  test "body is encrypted at rest" do
    note = personal_notes(:head_return_visit)
    note.update!(body: "<p>Ask what God's name is</p>")

    raw = ActionText::RichText.connection.select_value(ActionText::RichText.where(record: note, name: "body").select(:body).to_sql)

    assert_not_includes raw, "God's name"
    assert_includes note.reload.body.to_plain_text, "Ask what God's name is"
  end

  test "link_scriptures links the references typed in the body" do
    note = personal_notes(:head_return_visit)
    note.body = "<p>Start with Psalm 83:18</p>"

    note.link_scriptures
    note.save!

    assert_equal [ Bible::Reference.find("19:83:18") ], note.reload.body.body.attachables
  end

  test "the body can only hold scripture links" do
    note = personal_notes(:head_return_visit)
    note.body = "<p>A cat</p>#{remote_image_attachment}"

    assert_not note.valid?
    assert_equal [ "can only link scriptures" ], note.errors[:body]
  end

  test "a studies-only collection is invalid, and so is another person's collection" do
    note = personal_notes(:head_return_visit)

    note.collection = collections(:head_talks)
    assert_not note.valid?
    assert_equal [ "is only used in Personal study" ], note.errors[:collection]

    note.collection = collections(:spouse_ministry)
    assert_not note.valid?
    assert_equal [ "isn't one of yours" ], note.errors[:collection]

    [ collections(:head_bible_questions), collections(:head_quick_references), nil ].each do |collection|
      note.collection = collection
      assert note.valid?, "expected #{collection&.name || "no collection"} to be valid"
    end
  end

  test "matching finds by title, collection and tag, and not by body text" do
    head = users(:head)
    return_visit, daniel, family_worship = personal_notes(:head_return_visit, :head_daniel, :head_family_worship)
    family_worship.tag_with("Talk Prep", by: head)
    daniel.update!(body: "<p>Head of gold, chest of silver</p>")

    assert_equal [ return_visit ], head.personal_notes.matching("return visit").to_a
    assert_equal [ daniel ], head.personal_notes.matching("quick refer").to_a
    assert_equal [ family_worship ], head.personal_notes.matching("#talk-prep").to_a
    assert_empty head.personal_notes.matching("silver")
  end

  test "matching treats % and _ as plain characters" do
    assert_empty users(:head).personal_notes.matching("%")
    assert_empty users(:head).personal_notes.matching("_")
  end

  test "recent_first: the most recently updated first" do
    return_visit, daniel, family_worship = personal_notes(:head_return_visit, :head_daniel, :head_family_worship)
    return_visit.update_column(:updated_at, 3.days.ago)
    daniel.update_column(:updated_at, 1.hour.ago)
    family_worship.update_column(:updated_at, 2.days.ago)

    assert_equal [ daniel, family_worship, return_visit ], users(:head).personal_notes.recent_first.to_a
  end

  test "scripture_references lists each reference once, in order" do
    note = personal_notes(:head_return_visit)
    note.body = "<p>Psalm 83:18, then John 17:3, then Psalm 83:18 again and Revelation 21:3, 4</p>"
    note.link_scriptures
    note.save!

    assert_equal [ "Psalm 83:18", "John 17:3", "Revelation 21:3, 4" ], note.reload.scripture_references.map(&:to_s)
  end

  test "scripture_references is empty with no body" do
    assert_empty personal_notes(:head_family_worship).scripture_references
  end

  test "only its owner can tag it" do
    note = personal_notes(:head_return_visit)

    assert note.taggable_by?(users(:head))
    assert_not note.taggable_by?(users(:spouse))
    assert_equal [ "ministry" ], note.tap { it.tag_with("ministry", by: users(:head)) }.tags_for(users(:head)).map(&:name)
    assert_empty note.tags_for(users(:spouse))
  end

  test "deleting a collection nullifies the notes' collection_id" do
    note = personal_notes(:head_return_visit)
    note.update!(collection: collections(:head_bible_questions))

    collections(:head_bible_questions).destroy!

    assert_nil note.reload.collection_id
  end

  test "deleting a note deletes its taggings and body" do
    note = personal_notes(:head_return_visit)
    note.tag_with("ministry", by: users(:head))
    note.update!(body: "<p>Gone with it</p>")

    assert_difference -> { Tagging.count } => -1, -> { ActionText::RichText.count } => -1 do
      note.destroy!
    end
  end

  test "deleting the person deletes their notes" do
    newcomer = users(:newcomer)
    newcomer.personal_notes.create!(title: "Prayer", collection: newcomer.collections.add(name: "Bible questions"))

    assert_difference -> { PersonalNote.count } => -1, -> { Collection.count } => -1 do
      newcomer.destroy!
    end
  end

  test "color is none by default, and one of the seven" do
    note = users(:head).personal_notes.new(title: "Untitled")
    assert note.color_none?

    note.color = "teal"
    assert_not note.valid?
    assert note.errors[:color].any?

    note.color = "yellow"
    assert note.valid?
    assert_equal "Yellow", note.color_name
  end

  test "colored(:yellow) finds only the yellow notes" do
    personal_notes(:head_family_worship).update!(color: :yellow)

    assert_equal [ personal_notes(:head_family_worship) ], PersonalNote.colored(:yellow).to_a
    assert_equal [ personal_notes(:head_return_visit) ], PersonalNote.colored("green").to_a
  end

  test "database: a color outside the list raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      PersonalNote.insert!({ user_id: users(:head).id, title: "Teal", color: "teal" })
    end
  end

  test "database: a blank title raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      PersonalNote.insert!({ user_id: users(:head).id, title: "" })
    end
  end

  test "database: a title over 120 characters raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      PersonalNote.insert!({ user_id: users(:head).id, title: "x" * 121 })
    end
  end

  test "database: a note needs a person" do
    assert_raises(ActiveRecord::NotNullViolation) do
      PersonalNote.insert!({ user_id: nil, title: "No one's" })
    end
  end
end
