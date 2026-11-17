require "test_helper"

# The Bookmarks tab, and saving and removing a page or a scripture from a study or a note (docs/design/bookmarks.md,
# Pages and routes). Always through Current.user, so another person's bookmark, study or note is a 404.
class BookmarksControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  ARTICLE = { "url" => "https://www.jw.org/en/library/books/bible-questions-answered/", "title" => "Bible Questions Answered" }.freeze

  setup do
    @home = households(:home)
    @study = personal_studies(:head_suffering)
    personal_study_question(@study, status: "answered", answer: { "paragraphs" => [ "One." ] }, sources: [ ARTICLE ])
  end

  test "index: the person's own bookmarks, newest first, in the Bookmarks tab" do
    users(:head).bookmark(url: ARTICLE["url"], source: @study)
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home)

    assert_response :success
    assert_select "h1", "Notes"
    assert_select ".Subhead", text: /Pages and scriptures you saved to come back to. Only you can see them./
    assert_select "nav[aria-label='Notes, meeting notes and bookmarks'] a[aria-current=page]", text: /Bookmarks\s+2/
    assert_select "aside nav [aria-current=page]", text: "Notes"
    assert_select "main .Box-row", count: 2
    assert_select "main .Box-row:first-child a[href=?][target=_blank][rel~=noopener]", ARTICLE["url"], text: "Bible Questions Answered"
    assert_select "main .Box-row:first-child", text: /from Why does Jehovah allow suffering\?/
    assert_select "main .Box-row a[href=?]", household_personal_study_path(household_id: @home, id: @study)
    assert_select "main", text: /The Ransom/, count: 0
    assert_select "main a", text: "New note", count: 0
    assert_select "main p", text: /Bookmark a page or scripture with the bookmark button beside it in a personal study or a note./
  end

  test "index: a bookmark whose study was deleted shows no from" do
    personal_studies(:head_suffering).destroy!
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home)

    assert_select "main .Box-row", text: /Why Does God Allow Suffering\?/
    assert_select "main .Box-row", text: /from/, count: 0
  end

  test "index: the empty state when there are no bookmarks" do
    sign_in identities(:eli)

    get household_bookmarks_path(household_id: @home)

    assert_response :success
    assert_select ".blankslate h2", "No bookmarks yet."
    assert_select ".blankslate", text: /Bookmark a page or scripture with the bookmark button beside it/
  end

  test "index: 50 a page, with older ones on the next" do
    rows = Array.new(51) { { user_id: users(:eli).id, url: "https://www.jw.org/en/#{it}/", created_at: it.minutes.ago } }
    Bookmark.insert_all!(rows)
    sign_in identities(:eli)

    get household_bookmarks_path(household_id: @home)
    assert_select "main .Box-row", count: 50
    assert_select "a[href=?]", household_bookmarks_path(household_id: @home, page: 2), text: "Older bookmarks"

    get household_bookmarks_path(household_id: @home, page: 2)
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row a[href='https://www.jw.org/en/50/']"
    assert_select "a[href=?]", household_bookmarks_path(household_id: @home, page: 1), text: "Newer bookmarks"
  end

  # Removing the last bookmark on a later page refreshes that page, which is now past the end.
  test "index: a page past the last one goes to the last page that has bookmarks" do
    rows = Array.new(51) { { user_id: users(:eli).id, url: "https://www.jw.org/en/#{it}/", created_at: it.minutes.ago } }
    Bookmark.insert_all!(rows)
    sign_in identities(:eli)

    get household_bookmarks_path(household_id: @home, page: 3)
    assert_redirected_to household_bookmarks_path(household_id: @home, page: 2)

    users(:eli).bookmarks.recent_first.last.destroy!
    get household_bookmarks_path(household_id: @home, page: 2)
    assert_redirected_to household_bookmarks_path(household_id: @home)

    users(:eli).bookmarks.delete_all
    get household_bookmarks_path(household_id: @home, page: 2)
    assert_redirected_to household_bookmarks_path(household_id: @home)
  end

  test "index: ?kind=scripture lists only scriptures, each linking to jw.org" do
    users(:head).bookmarks.create!(scripture: "66:21:3-4")
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home, kind: "scripture")

    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row svg.octicon-book"
    assert_select "main .Box-row a[href=?][target=_blank][rel~=noopener]", Bible::Reference.find("66:21:3-4").jw_url, text: "Revelation 21:3, 4"
    assert_select "main .Box-row", text: /Scripture/
    assert_select "main .Box-row", text: /Why Does God Allow Suffering\?/, count: 0
    assert_select "segmented-control ul[aria-label=Show]" do
      assert_select "a[href=?]", household_bookmarks_path(household_id: @home), text: "All"
      assert_select "a[href=?]", household_bookmarks_path(household_id: @home, kind: "page"), text: "Pages"
      assert_select "a[href=?][aria-current=true]", household_bookmarks_path(household_id: @home, kind: "scripture"), text: "Scriptures"
    end
  end

  test "index: ?kind=page lists only pages" do
    users(:head).bookmarks.create!(scripture: "66:21:3-4")
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home, kind: "page")

    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row", text: /Why Does God Allow Suffering\?/
    assert_select "segmented-control a[aria-current=true]", text: "Pages"
  end

  test "index: an unknown kind is ignored" do
    users(:head).bookmarks.create!(scripture: "66:21:3-4")
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home, kind: "video")

    assert_response :success
    assert_select "main .Box-row", count: 2
    assert_select "segmented-control a[aria-current=true]", text: "All"
  end

  test "index: no scriptures yet, filtered to Scriptures" do
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home, kind: "scripture")

    assert_select "main .Box-row", count: 0
    assert_select ".blankslate h2", "No scriptures bookmarked yet."
    assert_select "segmented-control ul[aria-label=Show]"
  end

  test "index: the next page keeps the kind" do
    rows = Array.new(51) { { user_id: users(:eli).id, scripture: "19:#{it + 1}:1", created_at: it.minutes.ago } }
    Bookmark.insert_all!(rows)
    sign_in identities(:eli)

    get household_bookmarks_path(household_id: @home, kind: "scripture")

    assert_select "a[href=?]", household_bookmarks_path(household_id: @home, kind: "scripture", page: 2), text: "Older bookmarks"
    get household_bookmarks_path(household_id: @home, kind: "scripture", page: 3)
    assert_redirected_to household_bookmarks_path(household_id: @home, kind: "scripture", page: 2)
  end

  test "create: saves the page and fills every button for it" do
    sign_in identities(:head)

    assert_difference -> { users(:head).bookmarks.count } do
      post household_bookmarks_path(household_id: @home), params: { url: ARTICLE["url"], source_type: "PersonalStudy", source_id: @study.id }, as: :turbo_stream
    end

    assert_response :success
    bookmark = users(:head).bookmarks.recent_first.first
    assert_equal ARTICLE["url"], bookmark.url
    assert_equal @study, bookmark.source
    assert_select "turbo-stream[action=replace][targets=?]", "[data-bookmark-key='#{Digest::SHA256.hexdigest(ARTICLE["url"])}']" do
      assert_select "template button[aria-pressed=true][aria-label=?]", "Remove bookmark: Bible Questions Answered"
    end
  end

  test "create: a crafted title in the params is ignored" do
    sign_in identities(:head)

    post household_bookmarks_path(household_id: @home), params: { url: ARTICLE["url"], title: "Click here!", source_type: "PersonalStudy", source_id: @study.id }, as: :turbo_stream

    assert_equal "Bible Questions Answered", users(:head).bookmarks.find_by!(url: ARTICLE["url"]).title
  end

  test "create: a page that isn't in the study is refused" do
    sign_in identities(:head)

    assert_no_difference -> { Bookmark.count } do
      post household_bookmarks_path(household_id: @home), params: { url: "https://www.jw.org/en/whats-new/", source_type: "PersonalStudy", source_id: @study.id }, as: :turbo_stream
    end

    assert_response :unprocessable_content
  end

  test "create: another person's study is a 404" do
    sign_in identities(:spouse)

    assert_no_difference -> { Bookmark.count } do
      post household_bookmarks_path(household_id: @home), params: { url: ARTICLE["url"], source_type: "PersonalStudy", source_id: @study.id }, as: :turbo_stream
    end

    assert_response :not_found
  end

  test "create: a source of another type is a 404" do
    sign_in identities(:head)

    post household_bookmarks_path(household_id: @home), params: { url: ARTICLE["url"], source_type: "Goal", source_id: goals(:gospels).id }, as: :turbo_stream

    assert_response :not_found
  end

  test "create: saves a scripture from a study and fills every button for it" do
    personal_study_question(@study, status: "answered", answer: { "paragraphs" => [ "Comfort (Revelation 21:3, 4)." ] })
    sign_in identities(:head)

    assert_difference -> { users(:head).bookmarks.scriptures.count } do
      post household_bookmarks_path(household_id: @home), params: { scripture: "66:21:3-4", source_type: "PersonalStudy", source_id: @study.id }, as: :turbo_stream
    end

    assert_equal @study, users(:head).bookmark_for(scripture: "66:21:3-4").source
    assert_select "turbo-stream[action=replace][targets=?]", "[data-bookmark-key='#{Digest::SHA256.hexdigest("66:21:3-4")}']" do
      assert_select "template button[aria-pressed=true][aria-label=?]", "Remove bookmark: Revelation 21:3, 4"
    end
  end

  test "create: saves a scripture from a note" do
    note = note_linking("Psalm 83:18")
    sign_in identities(:head)

    post household_bookmarks_path(household_id: @home), params: { scripture: "19:83:18", source_type: "PersonalNote", source_id: note.id }, as: :turbo_stream

    assert_response :success
    assert_equal note, users(:head).bookmark_for(scripture: "19:83:18").source
    assert_select "template input[name=source_type][value=PersonalNote]"
  end

  test "create: a scripture that isn't in the note is refused" do
    note = note_linking("Psalm 83:18")
    sign_in identities(:head)

    assert_no_difference -> { Bookmark.count } do
      post household_bookmarks_path(household_id: @home), params: { scripture: "43:3:16", source_type: "PersonalNote", source_id: note.id }, as: :turbo_stream
    end

    assert_response :unprocessable_content
  end

  test "create: a page posted with a note is refused" do
    note = note_linking("Psalm 83:18")
    sign_in identities(:head)

    assert_no_difference -> { Bookmark.count } do
      post household_bookmarks_path(household_id: @home), params: { url: ARTICLE["url"], source_type: "PersonalNote", source_id: note.id }, as: :turbo_stream
    end

    assert_response :unprocessable_content
  end

  test "create: another person's note is a 404" do
    note = note_linking("Psalm 83:18")
    sign_in identities(:spouse)

    assert_no_difference -> { Bookmark.count } do
      post household_bookmarks_path(household_id: @home), params: { scripture: "19:83:18", source_type: "PersonalNote", source_id: note.id }, as: :turbo_stream
    end

    assert_response :not_found
  end

  test "create without Turbo goes back to the study" do
    sign_in identities(:head)

    post household_bookmarks_path(household_id: @home), params: { url: ARTICLE["url"], source_type: "PersonalStudy", source_id: @study.id },
                                                       headers: { "HTTP_REFERER" => household_personal_study_url(household_id: @home, id: @study) }

    assert_redirected_to household_personal_study_url(household_id: @home, id: @study)
  end

  test "destroy: removes the bookmark and empties every button for it" do
    bookmark = users(:head).bookmark(url: ARTICLE["url"], source: @study)
    sign_in identities(:head)

    assert_difference -> { Bookmark.count }, -1 do
      delete household_bookmark_path(household_id: @home, id: bookmark), params: { source_type: "PersonalStudy", source_id: @study.id }, as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][targets=?]", "[data-bookmark-key='#{Digest::SHA256.hexdigest(ARTICLE["url"])}']" do
      assert_select "template button[aria-pressed=false][aria-label=?]", "Bookmark: Bible Questions Answered"
    end
    assert_select "turbo-stream[action=refresh]", count: 0
  end

  test "destroy: a scripture bookmark empties every button for it, which save from the note the person is on" do
    note = note_linking("Psalm 23:4")
    bookmark = users(:head).bookmark(scripture: "19:23:4", source: note)
    sign_in identities(:head)

    assert_difference -> { Bookmark.count }, -1 do
      delete household_bookmark_path(household_id: @home, id: bookmark), params: { source_type: "PersonalNote", source_id: note.id }, as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][targets=?]", "[data-bookmark-key='#{Digest::SHA256.hexdigest("19:23:4")}']" do
      assert_select "template button[aria-pressed=false][aria-label=?]", "Bookmark: Psalm 23:4"
      assert_select "template input[name=scripture][value=?]", "19:23:4"
    end
  end

  # With no source, as from the Bookmarks tab: nothing to save it from again, so the empty button isn't drawn.
  test "destroy: a scripture bookmark with no source leaves no button to save it again" do
    bookmark = users(:head).bookmarks.create!(scripture: "19:23:4")
    sign_in identities(:head)

    delete household_bookmark_path(household_id: @home, id: bookmark), as: :turbo_stream

    assert_select "turbo-stream[action=replace] template button", count: 0
  end

  test "destroy on another study's page: the empty buttons save from the study the person is on" do
    other = personal_studies(:head_kindness)
    personal_study_question(other, status: "answered", answer: { "paragraphs" => [ "Two." ] }, sources: [ ARTICLE ])
    bookmark = users(:head).bookmark(url: ARTICLE["url"], source: @study)
    sign_in identities(:head)

    delete household_bookmark_path(household_id: @home, id: bookmark), params: { source_type: "PersonalStudy", source_id: other.id }, as: :turbo_stream

    assert_select "turbo-stream[action=replace] template" do
      assert_select "input[name=source_id][value=?]", other.id
      assert_select "input[name=url][value=?]", ARTICLE["url"]
    end
  end

  # The tab knows its own page, so it refreshes itself: the row, the count and the empty state all follow. Without a
  # request id, or Turbo would skip the refresh as an echo of its own request.
  test "destroy from the Bookmarks tab refreshes the tab" do
    sign_in identities(:head)

    delete household_bookmark_path(household_id: @home, id: bookmarks(:head_suffering_article)), params: { from: "list" }, as: :turbo_stream

    assert_select "turbo-stream[action=refresh]:not([request-id])"
  end

  test "destroy without Turbo goes back" do
    sign_in identities(:head)

    delete household_bookmark_path(household_id: @home, id: bookmarks(:head_suffering_article))

    assert_redirected_to household_bookmarks_url(household_id: @home)
  end

  test "destroy: another person's bookmark is a 404" do
    sign_in identities(:spouse)

    assert_no_difference -> { Bookmark.count } do
      delete household_bookmark_path(household_id: @home, id: bookmarks(:head_suffering_article)), as: :turbo_stream
    end

    assert_response :not_found
  end

  test "index: collections for notes, All bookmarks first, and my tags on a bookmark, each with its count" do
    bookmark = bookmarks(:head_suffering_article)
    bookmark.update!(collection: collections(:head_quick_references))
    bookmark.tag_with("comfort", by: users(:head))
    users(:head).bookmarks.create!(scripture: "19:23:4")
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home)

    assert_select "nav[aria-label=Collections] a" do |links|
      assert_equal [ "All bookmarks", "Bible questions", "Quick references" ], links.map { it.at_css(".ActionListItem-label").text.strip }
    end
    assert_select "nav[aria-label=Collections] a[aria-current=page]", text: /All bookmarks\s+2/
    assert_select "nav[aria-label=Collections] a[href=?]", household_bookmarks_path(household_id: @home, collection: collections(:head_quick_references).id), text: /Quick references\s+1/
    assert_select "nav[aria-label='My tags'] a", count: 1
    assert_select "nav[aria-label='My tags'] a[href=?]", household_bookmarks_path(household_id: @home, tag: "comfort"), text: /#comfort\s+1/
  end

  test "index: each row shows its comment, tags and collection" do
    bookmark = bookmarks(:head_suffering_article)
    bookmark.update!(comment: "Good for return visits.", collection: collections(:head_quick_references))
    bookmark.tag_with("comfort", by: users(:head))
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home)

    assert_select "##{dom_id(bookmark)}", text: /Good for return visits\./
    assert_select "##{dom_id(bookmark)} a.Label[href=?]", household_tag_path(household_id: @home, name: "comfort"), text: "#comfort"
    assert_select "##{dom_id(bookmark)}", text: /Quick references ·/
    assert_select "##{dom_id(bookmark)} dialog h1", "Edit bookmark"
  end

  test "index: filters by collection" do
    bookmark = bookmarks(:head_suffering_article)
    bookmark.update!(collection: collections(:head_quick_references))
    psalm = users(:head).bookmarks.create!(scripture: "19:23:4")
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home, collection: collections(:head_quick_references).id)

    assert_select "main .Box-row", count: 1
    assert_select "##{dom_id(bookmark)}"
    assert_select "##{dom_id(psalm)}", count: 0
    assert_select "nav[aria-label=Collections] a[aria-current=page]", text: /Quick references/
  end

  test "index: another person's collection, or a studies-only one, filters to nothing" do
    sign_in identities(:head)

    [ collections(:spouse_ministry), collections(:head_talks) ].each do |collection|
      get household_bookmarks_path(household_id: @home, collection: collection.id)

      assert_select "main .Box-row", count: 0
      assert_select ".blankslate h2", "No bookmarks match"
    end
  end

  test "index: filters by tag" do
    bookmark = bookmarks(:head_suffering_article)
    bookmark.tag_with("comfort", by: users(:head))
    users(:head).bookmarks.create!(scripture: "19:23:4")
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home, tag: "Comfort")

    assert_select "main .Box-row", count: 1
    assert_select "##{dom_id(bookmark)}"
    assert_select "a[aria-label='Remove filter #comfort']"
  end

  test "index: filters by q, through the decrypted comment" do
    bookmark = bookmarks(:head_suffering_article)
    psalm = users(:head).bookmarks.create!(scripture: "19:23:4", comment: "Read when someone is grieving")
    sign_in identities(:head)

    get household_bookmarks_path(household_id: @home, q: "grieving")

    assert_select "main .Box-row", count: 1
    assert_select "##{dom_id(psalm)}"
    assert_select "##{dom_id(bookmark)}", count: 0
    assert_select "input[name=q][value=grieving]"
  end

  test "update for the owner: title, comment and collection, and the row is replaced" do
    bookmark = bookmarks(:head_suffering_article)
    sign_in identities(:head)

    patch household_bookmark_path(household_id: @home, id: bookmark), as: :turbo_stream, params: {
      bookmark: { title: "Why suffering?", comment: "For return visits", collection_id: collections(:head_quick_references).id, url: "https://www.jw.org/en/other/" }
    }

    assert_response :success
    assert_select "turbo-stream[action=update][target=?]", dom_id(bookmark) do
      assert_select "template", text: /For return visits/
    end
    bookmark.reload
    assert_equal "Why suffering?", bookmark.title
    assert_equal "For return visits", bookmark.comment
    assert_equal collections(:head_quick_references), bookmark.collection
    assert_equal "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", bookmark.url
  end

  test "update: a blank collection takes it out of any collection, and a scripture's title is ignored" do
    psalm = users(:head).bookmarks.create!(scripture: "19:23:4", collection: collections(:head_quick_references))
    sign_in identities(:head)

    patch household_bookmark_path(household_id: @home, id: psalm), as: :turbo_stream, params: { bookmark: { title: "Mine", comment: "", collection_id: "" } }

    assert_response :success
    psalm.reload
    assert_nil psalm.collection
    assert_nil psalm.title
    assert_nil psalm.comment
  end

  test "update: another person's collection id: 404" do
    bookmark = bookmarks(:head_suffering_article)
    sign_in identities(:head)

    patch household_bookmark_path(household_id: @home, id: bookmark), as: :turbo_stream, params: { bookmark: { collection_id: collections(:spouse_ministry).id } }

    assert_response :not_found
    assert_nil bookmark.reload.collection
  end

  test "update: a refused save shows its errors in the dialog" do
    bookmark = bookmarks(:head_suffering_article)
    sign_in identities(:head)

    patch household_bookmark_path(household_id: @home, id: bookmark), as: :turbo_stream, params: { bookmark: { title: "", comment: "x" * 281, collection_id: collections(:head_talks).id } }

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=replace][target=?]", dom_id(bookmark, :edit) do
      assert_select "template", text: /Title can't be blank/
      assert_select "template", text: /Comment is too long/
      assert_select "template", text: /is only used in Personal study/
    end
    assert_equal "Why Does God Allow Suffering?", bookmark.reload.title
  end

  test "update: another person's bookmark: 404" do
    sign_in identities(:spouse)

    patch household_bookmark_path(household_id: @home, id: bookmarks(:head_suffering_article)), as: :turbo_stream, params: { bookmark: { comment: "Mine now" } }

    assert_response :not_found
    assert_nil bookmarks(:head_suffering_article).reload.comment
  end

  test "add and remove a tag on a bookmark" do
    bookmark = bookmarks(:head_suffering_article)
    sign_in identities(:head)

    post household_bookmark_taggings_path(household_id: @home, bookmark_id: bookmark), params: { name: "Ministry" }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action=replace][target=?] template a.Label", dom_id(bookmark, :tag_editor), text: "#ministry"
    assert_select "turbo-stream[action=update][target=?] template a.Label", dom_id(bookmark, :tags), text: "#ministry"
    assert_equal [ "ministry" ], bookmark.tags.map(&:name)

    delete household_bookmark_tagging_path(household_id: @home, bookmark_id: bookmark, id: tags(:head_ministry)), as: :turbo_stream
    assert_response :success
    assert_empty bookmark.tags.reload
  end

  test "tags on another person's bookmark: 404" do
    bookmark = bookmarks(:head_suffering_article)

    [
      -> { post household_bookmark_taggings_path(household_id: @home, bookmark_id: bookmark), params: { name: "ministry" }, as: :turbo_stream },
      -> { delete household_bookmark_tagging_path(household_id: @home, bookmark_id: bookmark, id: tags(:spouse_ministry)), as: :turbo_stream }
    ].each do |request|
      sign_in identities(:spouse) # a 404 doesn't keep the session
      request.call
      assert_response :not_found
    end
    assert_empty bookmark.tags
  end

  test "a non-member is a 404" do
    sign_in identities(:outsider)

    get household_bookmarks_path(household_id: @home)

    assert_response :not_found
  end

  private

  def note_linking(text)
    personal_notes(:head_return_visit).tap do |note|
      note.body = "<p>#{text}</p>"
      note.link_scriptures
      note.save!
    end
  end
end
