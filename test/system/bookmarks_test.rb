require "application_system_test_case"

# Bookmark a page from a study and find it in the Bookmarks tab (docs/design/bookmarks.md; frames bookmarks.png and
# personal-study-bookmarks.png).
class BookmarksTest < ApplicationSystemTestCase
  ARTICLE = { "url" => "https://www.jw.org/en/library/books/bible-questions-answered/", "title" => "Bible Questions Answered" }.freeze
  EDEN = { "url" => "https://wol.jw.org/en/wol/d/r1/lp-e/2017283", "title" => "The Issue Raised in Eden" }.freeze

  setup do
    @study = personal_studies(:head_suffering)
    personal_study_question(@study, status: "answered", sources: [ ARTICLE, EDEN ],
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering (James 1:13)." ], "next_questions" => [] })
    sign_in identities(:head)
  end

  test "bookmark a page from Pages used, its button in Sources fills too, then find it and remove it in the Bookmarks tab" do
    visit household_personal_study_url(household_id: households(:home), id: @study)
    # The notes editor lays the page out again as it starts; a click before then can land beside the button.
    assert_selector "lexxy-editor [contenteditable='true']"
    assert_turbo_idle

    within("ul[aria-label='Pages used']") { find("button[aria-label='Bookmark: Bible Questions Answered']").click }

    within("ul[aria-label='Pages used']") { assert_selector "button[aria-label='Remove bookmark: Bible Questions Answered'][aria-pressed=true]" }
    within("section[aria-labelledby=study-sources]") do
      assert_selector "button[aria-label='Remove bookmark: Bible Questions Answered'][aria-pressed=true]"
      assert_selector "button[aria-label='Bookmark: The Issue Raised in Eden'][aria-pressed=false]"
    end
    assert_accessible
    capture_screens("personal-study-bookmarks")

    click_on "Notes", match: :first
    within("nav[aria-label='Notes, meeting notes and bookmarks']") { click_on "Bookmarks" }

    assert_selector "h1", text: "Notes"
    assert_text "Pages and scriptures you saved to come back to. Only you can see them."
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] [aria-current=page]", text: "Bookmarks"
    assert_selector "aside nav [aria-current=page]", text: "Notes"
    within("main .Box-row", text: "Bible Questions Answered") do
      assert_link "Bible Questions Answered", href: ARTICLE["url"]
      assert_text "jw.org"
      assert_link "Why does Jehovah allow suffering?"
    end
    assert_text "Bookmark a page or scripture with the bookmark button beside it in a personal study or a note."
    assert_accessible
    capture_screens("bookmarks")

    find("button[aria-label='Remove bookmark: Bible Questions Answered']").click

    assert_no_selector "main .Box-row", text: "Bible Questions Answered"
    assert_selector "main .Box-row", count: 1
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a", text: /Bookmarks\s+1/
    assert_not users(:head).bookmarks.exists?(url: ARTICLE["url"])
  end

  test "bookmark a scripture from a study and one from a note, filter to Scriptures, and each opens jw.org's finder" do
    note = personal_notes(:head_return_visit)
    note.body = "<p>Then read Psalm 83:18 and John 17:3.</p>"
    note.link_scriptures
    note.save!

    visit household_personal_study_url(household_id: households(:home), id: @study)
    assert_selector "lexxy-editor [contenteditable='true']"
    assert_turbo_idle
    within("section[aria-labelledby=study-scriptures]") do
      assert_link "James 1:13", href: Bible::Reference.find("59:1:13").jw_url
      find("button[aria-label='Bookmark: James 1:13']").click
      assert_selector "button[aria-label='Remove bookmark: James 1:13'][aria-pressed=true]"
    end
    assert_accessible
    # On a phone the box is in the Sources tab, which the page test opens; here, desktop beside the conversation.
    capture_screens("personal-study-scriptures", scroll_to: "section[aria-labelledby=study-scriptures]", viewports: { desktop: ScreenshotHelper::VIEWPORTS[:desktop] })

    visit household_personal_note_url(household_id: households(:home), id: note)
    assert_selector "lexxy-editor [contenteditable='true']"
    assert_turbo_idle
    within("section[aria-labelledby=note-scriptures]") do
      find("button[aria-label='Bookmark: Psalm 83:18']").click
      assert_selector "button[aria-label='Remove bookmark: Psalm 83:18'][aria-pressed=true]"
      assert_selector "button[aria-label='Bookmark: John 17:3'][aria-pressed=false]"
    end
    assert_accessible
    capture_screens("note-bookmarks")

    visit household_bookmarks_url(household_id: households(:home))
    within("segmented-control ul[aria-label=Show]") { click_on "Scriptures" }

    assert_selector "segmented-control a[aria-current=true]", text: "Scriptures"
    assert_selector "main .Box-row", count: 2
    assert_no_selector "main .Box-row", text: "Why Does God Allow Suffering?"
    within("main .Box-row", text: "Psalm 83:18") do
      assert_selector "svg.octicon-book"
      assert_text "Scripture"
      assert_selector "a[href='https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=19083018'][target=_blank][rel~=noopener]", text: "Psalm 83:18"
      assert_link "Questions for my return visit"
    end
    assert_selector "main .Box-row a[href='#{Bible::Reference.find("59:1:13").jw_url}']", text: "James 1:13"
    assert_accessible
    capture_screens("bookmarks-scriptures")
  end

  test "open Edit, add a comment, pick a collection, add a tag and save; then filter by the tag and search the comment" do
    users(:head).bookmarks.create!(scripture: "19:23:4", source: personal_notes(:head_return_visit))
    article = bookmarks(:head_suffering_article)

    visit household_bookmarks_url(household_id: households(:home))
    within("##{ActionView::RecordIdentifier.dom_id(article)}") { click_on "Edit" }

    within("dialog[open]") do
      assert_selector "h1", text: "Edit bookmark"
      assert_text "jw.org · saved from “Why does Jehovah allow suffering?”"
      assert_field "Title", with: "Why Does God Allow Suffering?"
      fill_in "Comment", with: "Good for return visits. The video at the end helps."
      select "Quick references", from: "Collection"
      find_field("Add a tag").send_keys("Comfort", :enter)
      assert_selector "a.Label", text: "#comfort"
    end
    assert_accessible
    capture_screens("bookmark-edit")

    within("dialog[open]") { click_on "Save" }

    assert_no_selector "dialog[open]"
    within("##{ActionView::RecordIdentifier.dom_id(article)}") do
      assert_text "Good for return visits. The video at the end helps."
      assert_selector "a.Label", text: "#comfort"
      assert_text "Quick references ·"
    end
    article.reload
    assert_equal "Good for return visits. The video at the end helps.", article.comment
    assert_equal collections(:head_quick_references), article.collection
    assert_equal [ "comfort" ], article.tags.map(&:name)

    # Saving replaces the row only, so the new tag reaches My tags with the next visit.
    visit household_bookmarks_url(household_id: households(:home))
    within("nav[aria-label='My tags']") { click_on "#comfort" }
    assert_selector "a[aria-label='Remove filter #comfort']"
    assert_selector "main .Box-row", count: 1
    assert_selector "main .Box-row", text: "Why Does God Allow Suffering?"

    visit household_bookmarks_url(household_id: households(:home))
    assert_selector "main .Box-row", count: 2
    fill_in "Search titles, comments, collections and tags", with: "video at the end\n"
    assert_selector "main .Box-row", count: 1
    assert_selector "main .Box-row", text: "Why Does God Allow Suffering?"
    assert_accessible

    users(:head).update!(appearance: "dark")
    visit household_bookmarks_url(household_id: households(:home))
    assert_selector "body[data-color-mode=dark]"
    assert_selector "main .Box-row", text: "Good for return visits."
    assert_accessible
    capture_screens("bookmarks-dark")
  end

  test "no bookmarks yet" do
    users(:head).bookmarks.delete_all

    visit household_bookmarks_url(household_id: households(:home))

    assert_selector "h2", text: "No bookmarks yet."
    assert_accessible
    capture_screens("bookmarks-empty")
  end
end
