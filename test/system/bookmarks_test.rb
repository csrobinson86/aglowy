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

  test "no bookmarks yet" do
    users(:head).bookmarks.delete_all

    visit household_bookmarks_url(household_id: households(:home))

    assert_selector "h2", text: "No bookmarks yet."
    assert_accessible
    capture_screens("bookmarks-empty")
  end
end
