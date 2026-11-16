require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  test "for_studies and for_notes" do
    head = users(:head)

    assert_equal collections(:head_bible_questions, :head_talks), head.collections.for_studies.positioned.to_a
    assert_equal collections(:head_bible_questions, :head_quick_references), head.collections.for_notes.positioned.to_a
  end

  test "add puts a new collection last in the person's list, used in both by default" do
    collection = users(:head).collections.add(name: "Convention 2027")

    assert collection.persisted?
    assert_equal 4, collection.position
    assert collection.used_in_both?
    assert_equal 1, users(:outsider).collections.add(name: "Ministry").position
  end

  test "a name is 1 to 40 characters, squished, and the person's only one of that name" do
    collection = users(:head).collections.new(name: "  Convention   2027 ")
    assert_equal "Convention 2027", collection.name

    [ "", "x" * 41, "Bible questions" ].each do |name|
      collection.name = name
      assert_not collection.valid?, "expected #{name.inspect} to be refused"
      assert collection.errors[:name].any?
    end

    assert users(:outsider).collections.new(name: "Bible questions").valid?
  end

  test "used_in is both, studies or notes" do
    collection = collections(:head_talks)

    collection.used_in = "goals"

    assert_not collection.valid?
    assert collection.errors[:used_in].any?
  end

  test "changing used_in to notes is refused while a study is in it" do
    collection = collections(:head_talks)

    assert_not collection.update(used_in: "notes")
    assert_equal [ "1 study is in this collection. Move it first." ], collection.errors.full_messages
    assert collection.reload.used_in_studies?
  end

  test "changing used_in away from studies is fine once it's empty, and between both and studies always" do
    assert collections(:head_bible_questions).update(used_in: "studies")

    personal_studies(:head_kindness).update!(collection: nil)
    assert collections(:head_talks).update(used_in: "notes")
  end

  test "renaming a collection that has studies in it is fine" do
    assert collections(:head_talks).update(name: "Talks")
  end

  test "a study can't be put in a notes-only collection" do
    study = personal_studies(:head_daniel)

    study.collection = collections(:head_quick_references)

    assert_not study.valid?
    assert_equal [ "Collection is only used in Notes" ], study.errors.full_messages
  end

  test "a study can't be put in another person's collection" do
    study = personal_studies(:head_daniel)

    study.collection = collections(:spouse_ministry)

    assert_not study.valid?
    assert_equal [ "Collection isn't one of yours" ], study.errors.full_messages
  end

  test "database: a duplicate name for the same person raises RecordNotUnique" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Collection.insert!({ user_id: users(:head).id, name: "Bible questions", used_in: "both", position: 9 })
    end
  end

  test "database: a used_in of goals raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      collections(:head_talks).update_column(:used_in, "goals")
    end
  end

  test "database: a blank name raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      collections(:head_talks).update_column(:name, "")
    end
  end

  test "database: a name over 40 characters raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      collections(:head_talks).update_column(:name, "x" * 41)
    end
  end

  test "database: a collection needs a position" do
    assert_raises(ActiveRecord::NotNullViolation) do
      collections(:head_talks).update_column(:position, nil)
    end
  end
end
