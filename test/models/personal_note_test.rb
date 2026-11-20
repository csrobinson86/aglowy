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

  # A study's note (docs/design/notes.md, PersonalNote: personal_study_id).
  test "a note can't link another person's study" do
    note = personal_notes(:head_return_visit)
    note.personal_study = personal_studies(:spouse_ransom)

    assert_not note.valid?
    assert_equal [ "must be your own study" ], note.errors[:personal_study]
  end

  test "deleting the study keeps its note and drops the link" do
    study = personal_studies(:head_suffering)
    note = study.with_lock { study.start_note }

    study.destroy!

    assert_nil note.reload.personal_study_id
  end

  test "deleting the note deletes its savings, so the answers can be saved again" do
    question = personal_study_question(status: "answered", answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering." ], "next_questions" => [] })
    note = question.save_to_note

    assert_difference -> { PersonalStudy::Question::NoteSaving.count } => -1 do
      note.destroy!
    end
    assert_not_predicate question.reload, :saved_to_note?
  end

  test "database: a study has one note" do
    study = personal_studies(:head_suffering)
    study.with_lock { study.start_note }

    assert_raises(ActiveRecord::RecordNotUnique) do
      PersonalNote.insert!({ user_id: users(:head).id, personal_study_id: study.id, title: "Another", color: "none" })
    end
  end

  # docs/design/notes.md, A note: the version check.
  test "revise saves with a matching base, links scriptures, and moves updated_at" do
    note = personal_notes(:head_daniel)
    base = note.base

    travel 1.minute do
      assert note.revise({ title: "Daniel 2", color: "blue", body: "<p>Read Daniel 2:44</p>" }, base:)
    end

    note.reload
    assert_equal "Daniel 2", note.title
    assert note.color_blue?
    assert_equal [ Bible::Reference.find("27:2:44") ], note.body.body.attachables
    assert_not_equal base, note.base
  end

  test "revise refuses a stale base and changes nothing, leaving the note as it is now" do
    note = personal_notes(:head_daniel)
    stale = note.base
    travel(1.minute) { PersonalNote.find(note.id).update!(title: "Changed elsewhere") }

    assert_raises(ActiveRecord::StaleObjectError) do
      note.revise({ title: "Mine", color: "blue", body: "<p>Mine</p>" }, base: stale)
    end

    assert_equal "Changed elsewhere", note.title
    note.reload
    assert_equal "Changed elsewhere", note.title
    assert note.color_orange?
    assert_nil note.body.body
  end

  test "revise refuses a missing or malformed base" do
    note = personal_notes(:head_daniel)

    [ nil, "", "yesterday" ].each do |base|
      assert_raises(ActiveRecord::StaleObjectError) { note.revise({ title: "Mine" }, base:) }
    end
    assert_equal "Daniel 2 image: quick reference", note.reload.title
  end

  test "revise ignores tag names" do
    note = personal_notes(:head_daniel)

    assert_no_difference -> { Tagging.count } do
      assert note.revise({ title: "Daniel 2", tag_names: "ministry prayer" }, base: note.base)
    end
    assert_empty note.reload.tags
  end

  test "revise with an invalid title saves nothing and keeps the errors" do
    note = personal_notes(:head_daniel)

    assert_not note.revise({ title: "x" * 121 }, base: note.base)

    assert note.errors[:title].any?
    assert_equal "Daniel 2 image: quick reference", note.reload.title
  end

  test "tag_with and untag leave updated_at alone, so a revise with the base from before tagging still saves" do
    note = personal_notes(:head_daniel)
    base = note.base

    travel 1.minute do
      note.tag_with("ministry", by: users(:head))
      note.untag(tags(:head_ministry))
      note.tag_with("prayer", by: users(:head))
    end

    assert_equal base, note.reload.base
    assert note.revise({ title: "Daniel 2" }, base:)
    assert_equal [ "prayer" ], note.reload.tags.map(&:name)
  end

  test "the ten colors, in order: none, then Casey's nine; the filter has all but none" do
    assert_equal %w[ none yellow orange red pink purple blue green brown gray ], PersonalNote.colors.keys
    assert_equal %w[ yellow orange red pink purple blue green brown gray ], PersonalNote::FILTER_COLORS
  end

  test "red, brown and gray save" do
    note = personal_notes(:head_family_worship)

    %w[ red brown gray ].each do |color|
      note.update!(color:)
      assert_equal color, note.reload.color
      assert_equal color.humanize, note.color_name
    end
  end

  test "database: red, brown and gray are in the color check" do
    %w[ red brown gray ].each do |color|
      PersonalNote.insert!({ user_id: users(:head).id, title: color.humanize, color: })
    end

    assert_equal %w[ brown gray red ], users(:head).personal_notes.where(title: %w[ Red Brown Gray ]).pluck(:color).sort
  end

  test "color is none by default, and one of the ten" do
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
