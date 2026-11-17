require "test_helper"

# A saved jw.org page (docs/design/bookmarks.md, Bookmark). Scriptures come with #227; the table holds them already.
class BookmarkTest < ActiveSupport::TestCase
  PAGE = "https://www.jw.org/en/library/books/bible-questions-answered/".freeze

  test "a fragment and utm_ parameters are dropped, so the same page saved twice is one bookmark" do
    bookmark = users(:head).bookmarks.create!(url: "#{PAGE}?utm_source=share&q=1#comments", title: "Bible Questions Answered")

    assert_equal "#{PAGE}?q=1", bookmark.url
    assert_raises(ActiveRecord::RecordNotUnique) { users(:head).bookmarks.create!(url: "#{PAGE}?q=1&utm_medium=email") }
  end

  test "a page on another host, or over http, is invalid" do
    [ "https://example.com/", "http://www.jw.org/en/", "https://jw.org.example.com/" ].each do |url|
      bookmark = users(:head).bookmarks.new(url: url)

      assert_not bookmark.valid?, url
      assert_includes bookmark.errors[:url], "must be a page on jw.org or wol.jw.org"
    end
  end

  test "a page and a scripture together, or neither, are invalid" do
    assert_not users(:head).bookmarks.new(url: PAGE, scripture: "19:23:4").valid?
    assert_not users(:head).bookmarks.new.valid?
  end

  test "a scripture must be one that exists" do
    assert users(:head).bookmarks.new(scripture: "19:23:4").valid?
    assert_includes users(:head).bookmarks.new(scripture: "19:23:99").tap(&:valid?).errors[:scripture], "isn't a Bible reference"
  end

  test "a title over 120 characters and a comment over 280 are invalid" do
    bookmark = users(:head).bookmarks.new(url: PAGE, title: "x" * 121, comment: "x" * 281)

    assert_not bookmark.valid?
    assert bookmark.errors.of_kind?(:title, :too_long)
    assert bookmark.errors.of_kind?(:comment, :too_long)
  end

  test "a person can have at most 2,000 bookmarks" do
    rows = Array.new(Bookmark::LIMIT - 1) { { user_id: users(:spouse).id, url: "https://www.jw.org/en/#{it}/" } }
    Bookmark.insert_all!(rows)

    bookmark = users(:spouse).bookmarks.new(url: PAGE)
    assert_not bookmark.valid?
    assert_includes bookmark.errors[:base], "You already have 2,000 bookmarks, the most you can have"
    assert users(:head).bookmarks.new(url: PAGE).valid?
  end

  test "title and comment are encrypted at rest" do
    bookmark = users(:head).bookmarks.create!(url: PAGE, title: "Bible Questions Answered", comment: "For return visits")
    raw = Bookmark.connection.select_one(Bookmark.where(id: bookmark.id).select(:title, :comment).to_sql)

    assert_not_includes raw["title"], "Bible Questions"
    assert_not_includes raw["comment"], "return visits"
    assert_equal "Bible Questions Answered", bookmark.reload.title
  end

  test "deleting the study keeps the bookmark with no source" do
    bookmark = bookmarks(:head_suffering_article)

    personal_studies(:head_suffering).destroy!

    bookmark.reload
    assert_nil bookmark.source_type
    assert_nil bookmark.source_id
  end

  test "deleting a note keeps its bookmarks too" do
    note = personal_notes(:head_daniel)
    bookmark = users(:head).bookmarks.create!(scripture: "27:2:44", source: note)

    note.destroy!

    assert_nil bookmark.reload.source
  end

  test "pages, scriptures and recent_first" do
    scripture = users(:head).bookmarks.create!(scripture: "19:23:4")
    page = bookmarks(:head_suffering_article)

    assert_equal [ page ], users(:head).bookmarks.pages.to_a
    assert_equal [ scripture ], users(:head).bookmarks.scriptures.to_a
    assert_equal [ scripture, page ], users(:head).bookmarks.recent_first.to_a
  end

  test "kind is page or scripture" do
    assert_equal :page, bookmarks(:head_suffering_article).kind
    assert_equal :scripture, Bookmark.new(scripture: "19:23:4").kind
  end

  test "database: both a url and a scripture raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      Bookmark.insert!({ user_id: users(:head).id, url: PAGE, scripture: "19:23:4" })
    end
  end

  test "database: neither a url nor a scripture raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      Bookmark.insert!({ user_id: users(:head).id })
    end
  end

  # SQL straight to the row, past the normalizer that would have made it nil.
  test "database: https://example.com/ raises CheckViolation" do
    error = assert_raises(ActiveRecord::CheckViolation) do
      Bookmark.where(id: bookmarks(:head_suffering_article)).update_all("url = 'https://example.com/'")
    end
    assert_match "bookmarks_url_check", error.message
  end

  test "database: a scripture that isn't a reference id raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      Bookmark.insert!({ user_id: users(:head).id, scripture: "Psalm 23" })
    end
  end

  test "database: a source of another type raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      bookmarks(:head_suffering_article).update_column(:source_type, "Goal")
    end
  end

  test "database: a source type without its id raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      bookmarks(:head_suffering_article).update_column(:source_id, nil)
    end
  end

  test "database: the same page twice for one person raises RecordNotUnique" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Bookmark.insert!({ user_id: users(:head).id, url: bookmarks(:head_suffering_article).url })
    end
  end
end
