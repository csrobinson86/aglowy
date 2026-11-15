require "test_helper"

class Bible::ReferenceTest < ActiveSupport::TestCase
  test "psalms 37:8,9, Ps 37:8-9 and ps 37 8-9 parse to Psalm 37:8-9" do
    expected = reference(19, 37, 8, 9)

    assert_equal expected, Bible::Reference.parse("psalms 37:8,9")
    assert_equal expected, Bible::Reference.parse("Ps 37:8-9")
    assert_equal expected, Bible::Reference.parse("ps 37 8-9")
  end

  test "parse reads one verse, a whole chapter and a numbered book" do
    assert_equal reference(19, 37, 8, 8), Bible::Reference.parse("ps 37 8")
    assert_equal reference(19, 23), Bible::Reference.parse("Psalm 23")
    assert_equal reference(46, 13, 4, 7), Bible::Reference.parse("1 cor 13:4-7")
    assert_equal reference(40, 24, 14, 14), Bible::Reference.parse("matt 24:14")
    assert_equal reference(1, 1, 1, 1), Bible::Reference.parse("Gen. 1:1")
  end

  test "to_s writes the reference our way" do
    assert_equal "Psalm 37:8, 9", reference(19, 37, 8, 9).to_s
    assert_equal "Psalm 37:8-11", reference(19, 37, 8, 11).to_s
    assert_equal "Psalm 23", reference(19, 23).to_s
    assert_equal "1 Corinthians 13:4-7", reference(46, 13, 4, 7).to_s
    assert_equal "Matthew 24:14", reference(40, 24, 14, 14).to_s
  end

  test "jw_url for Psalm 37:8, 9" do
    assert_equal "https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=19037008-19037009", reference(19, 37, 8, 9).jw_url
  end

  test "jw_url for a whole chapter runs from verse 1 to its last verse" do
    assert_equal "https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=19023001-19023006", reference(19, 23).jw_url
  end

  test "jw_url for one verse" do
    assert_equal "https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=40024014", reference(40, 24, 14, 14).jw_url
  end

  test "parse returns nil for Psalm 151, Psalm 37:41, Psalm 37:8, 10, Hezekiah 1:1 and an empty string" do
    [ "Psalm 151", "Psalm 37:41", "Psalm 37:8, 10", "Hezekiah 1:1", "" ].each do |text|
      assert_nil Bible::Reference.parse(text), text
    end
  end

  test "parse returns nil for a backwards range, a verse 0, a book prefix and no text at all" do
    [ "Psalm 37:9-8", "Psalm 37:0", "Psal 37:8", "Peter 1:1", "Psalm", nil ].each do |text|
      assert_nil Bible::Reference.parse(text), text.inspect
    end
  end

  test "find round-trips the id" do
    [ reference(19, 37, 8, 9), reference(19, 23), reference(40, 24, 14, 14) ].each do |reference|
      assert_equal reference, Bible::Reference.find(reference.id)
    end
    assert_equal "19:37:8-9", reference(19, 37, 8, 9).id
    assert_equal "19:23", reference(19, 23).id
    assert_equal "40:24:14", reference(40, 24, 14, 14).id
  end

  test "find raises RecordNotFound for an id that isn't a reference" do
    [ "bad", "67:1:1", "19:151", "19:37:41", "19:37:9-8", "", nil ].each do |id|
      assert_raises(ActiveRecord::RecordNotFound, id.inspect) { Bible::Reference.find(id) }
    end
  end

  test "find does no database work" do
    assert_no_queries { Bible::Reference.find("19:37:8-9") }
  end

  test "to_sgid and GlobalID::Locator.locate_signed round-trip" do
    psalm = reference(19, 37, 8, 9)

    assert_equal psalm, GlobalID::Locator.locate_signed(psalm.to_sgid)
    assert_equal psalm, GlobalID::Locator.locate_signed(psalm.attachable_sgid, for: ActionText::Attachable::LOCATOR_NAME)
  end

  test "attachable_content_type is application/vnd.actiontext.scripture" do
    assert_equal "application/vnd.actiontext.scripture", reference(19, 37, 8, 9).attachable_content_type
  end

  test "the attachable renders with the reference partial and reads as the reference in plain text" do
    psalm = reference(19, 37, 8, 9)

    assert_equal "bible/references/reference", psalm.to_attachable_partial_path
    assert_equal "bible/references/editor", psalm.to_trix_content_attachment_partial_path
    assert_equal "Psalm 37:8, 9", psalm.attachable_plain_text_representation
  end

  test "an attachment in rich text finds its reference and reads as plain text" do
    psalm = reference(19, 37, 8, 9)
    content = ActionText::Content.new(%(<p>Read <action-text-attachment sgid="#{psalm.attachable_sgid}" content-type="#{psalm.attachable_content_type}"></action-text-attachment></p>))

    assert_equal [ psalm ], content.attachables
    assert_equal "Read Psalm 37:8, 9", content.to_plain_text
  end

  private
    def reference(book, chapter, first_verse = nil, last_verse = nil)
      Bible::Reference.new(Bible::Book.find(book), chapter, first_verse, last_verse)
    end
end
