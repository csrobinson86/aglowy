require "test_helper"

# The bookmark button beside a page or a scripture (docs/design/bookmarks.md, The bookmark button).
class BookmarkButtonComponentTest < ViewComponent::TestCase
  URL = "https://www.jw.org/en/library/books/bible-questions-answered/".freeze

  setup do
    @home = households(:home)
    @study = personal_studies(:head_suffering)
  end

  test "not saved: an empty bookmark that saves the page from its source" do
    render_inline(BookmarkButtonComponent.new(url: URL, title: "Bible Questions Answered", source: @study, bookmarked: {}, household: @home))

    assert_selector "[data-bookmark-key='#{Digest::SHA256.hexdigest(URL)}'] form[action='/#{@home.id}/bookmarks'][method=post]"
    assert_selector "input[name=_method]", count: 0
    assert_selector "input[type=hidden][name=url][value='#{URL}']", visible: :hidden
    assert_selector "input[type=hidden][name=source_type][value=PersonalStudy]", visible: :hidden
    assert_selector "input[type=hidden][name=source_id][value='#{@study.id}']", visible: :hidden
    assert_selector "button[type=submit][aria-pressed=false][aria-label='Bookmark: Bible Questions Answered'] svg.octicon-bookmark"
    assert_no_selector "input[name=title]", visible: :all
  end

  test "saved: a filled bookmark that removes it" do
    bookmark = bookmarks(:head_suffering_article)

    render_inline(BookmarkButtonComponent.new(url: bookmark.url, title: bookmark.title, source: @study, bookmarked: { bookmark.url => bookmark.id }, household: @home))

    assert_selector "form[action='/#{@home.id}/bookmarks/#{bookmark.id}'] input[name=_method][value=delete]", visible: :all
    assert_selector "button[type=submit][aria-pressed=true][aria-label='Remove bookmark: Why Does God Allow Suffering?'] svg.octicon-bookmark-fill"
    assert_selector "input[type=hidden][name=source_id][value='#{@study.id}']", visible: :hidden
    assert_no_selector "input[name=url]", visible: :all
  end

  test "the key is a digest of the URL, never the URL" do
    render_inline(BookmarkButtonComponent.new(url: URL, title: "Bible Questions Answered", source: @study, bookmarked: {}, household: @home))

    assert_no_selector "[data-bookmark-key*='jw.org']"
    assert_no_selector "[id*='jw.org']"
  end

  test "a page with no title is labelled with its site" do
    render_inline(BookmarkButtonComponent.new(url: URL, title: nil, source: @study, bookmarked: {}, household: @home))

    assert_selector "button[aria-label='Bookmark: jw.org']"
  end

  test "from the Bookmarks tab, removing says so, so the tab refreshes" do
    bookmark = bookmarks(:head_suffering_article)

    render_inline(BookmarkButtonComponent.new(url: bookmark.url, title: bookmark.title, source: nil, bookmarked: { bookmark.url => bookmark.id }, household: @home, from_list: true))

    assert_selector "input[type=hidden][name=from][value=list]", visible: :hidden
  end

  test "a link that isn't a jw.org or wol.jw.org page has no button" do
    render_inline(BookmarkButtonComponent.new(url: "https://example.com/", title: "Elsewhere", source: @study, bookmarked: {}, household: @home))

    assert_no_selector "button"
  end

  test "an unsaved page with no source has no button: removed from the tab after its study was deleted" do
    render_inline(BookmarkButtonComponent.new(url: URL, title: "Bible Questions Answered", source: nil, bookmarked: {}, household: @home))

    assert_no_selector "button"
  end

  test "a scripture: an empty bookmark that saves it from its note, labelled with the reference" do
    note = personal_notes(:head_return_visit)
    reference = Bible::Reference.find("66:21:3-4")

    render_inline(BookmarkButtonComponent.new(scripture: reference, source: note, bookmarked: {}, household: @home))

    assert_selector "[data-bookmark-key='#{Digest::SHA256.hexdigest("66:21:3-4")}'] form[method=post]"
    assert_selector "input[type=hidden][name=scripture][value='66:21:3-4']", visible: :hidden
    assert_selector "input[type=hidden][name=source_type][value=PersonalNote]", visible: :hidden
    assert_selector "button[aria-pressed=false][aria-label='Bookmark: Revelation 21:3, 4']"
    assert_no_selector "input[name=url]", visible: :all
  end

  test "a saved scripture: a filled bookmark that removes it" do
    reference = Bible::Reference.find("19:23:4")

    render_inline(BookmarkButtonComponent.new(scripture: reference, source: @study, bookmarked: { "19:23:4" => "abc" }, household: @home))

    assert_selector "form[action='/#{@home.id}/bookmarks/abc']"
    assert_selector "button[aria-pressed=true][aria-label='Remove bookmark: Psalm 23:4']"
    assert_no_selector "input[name=scripture]", visible: :all
  end
end
