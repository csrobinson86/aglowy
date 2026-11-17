require "application_system_test_case"

# Bookmarks on a phone (docs/design/bookmarks.md, Pages and routes; frame phone-bookmarks.png): the tabs fill the width,
# collections and tags fold into the "All bookmarks ▾" menu, Show stays a segmented control, and each row is its title
# on one line over one muted line, with Edit and Remove in a 44px "⋯" menu. Bookmark buttons on studies and notes are
# 44px targets too.
class BookmarksPhoneTest < ApplicationSystemTestCase
  setup do
    @article = bookmarks(:head_suffering_article)
    @article.update!(collection: collections(:head_quick_references), comment: "Good for return visits.")
    @article.tag_with("ministry", by: users(:head))
    @psalm = users(:head).bookmarks.create!(scripture: "19:23:4", source: personal_notes(:head_return_visit))
    @psalm.tag_with("comfort", by: users(:head))

    sign_in identities(:head)
    visit root_url
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
    emulate_touch(true)
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "pick a collection from the menu" do
    visit bookmarks_url

    assert_no_selector "nav[aria-label=Collections]"
    assert_no_selector "nav[aria-label='My tags']"
    tabs = find("nav[aria-label='Notes, meeting notes and bookmarks'] ul")
    assert_in_delta tabs.evaluate_script("this.getBoundingClientRect().left"), tabs.first("li").evaluate_script("this.getBoundingClientRect().left"), 1, "the tabs don't fill the width"
    assert_in_delta tabs.evaluate_script("this.getBoundingClientRect().right"), tabs.all("li").last.evaluate_script("this.getBoundingClientRect().right"), 1, "the tabs don't fill the width"
    assert_selector "segmented-control ul[aria-label=Show]"
    within(row(@article)) do
      title = find_link("Why Does God Allow Suffering?")
      assert_operator title.evaluate_script("this.offsetHeight"), :<, 2 * title.evaluate_script("parseFloat(getComputedStyle(this).lineHeight)"), "the title is more than one line"
      assert_text "jw.org · Quick references · #ministry"
      assert_no_text "Good for return visits."
      assert_no_button "Edit"
      assert_no_selector "button[aria-label='Remove bookmark: Why Does God Allow Suffering?']"
    end
    within(row(@psalm)) { assert_text "Scripture · #comfort" }
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")

    click_on "All bookmarks"
    assert_selector "[role=menuitem]", text: "#comfort"
    all("[role=menuitem]").each do |item|
      assert_operator item.evaluate_script("this.offsetHeight"), :>=, 44, "#{item.text} is too small to tap"
    end
    find("[role=menuitem]", text: "Quick references").click

    assert_button "Quick references"
    assert_selector "main .Box-row", count: 1
    assert_selector "main .Box-row", text: "Why Does God Allow Suffering?"
    assert_accessible

    visit bookmarks_url
    assert_selector "main .Box-row", count: 2
    capture_screens("phone-bookmarks", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "filter to Scriptures" do
    visit bookmarks_url

    within("segmented-control ul[aria-label=Show]") { click_on "Scriptures" }

    assert_selector "segmented-control a[aria-current=true]", text: "Scriptures"
    assert_selector "main .Box-row", count: 1
    within(row(@psalm)) do
      assert_selector "svg.octicon-book"
      assert_link "Psalm 23:4", href: Bible::Reference.find("19:23:4").jw_url
      assert_text "Scripture · #comfort"
    end
    assert_accessible
  end

  test "edit a bookmark from its ⋯ menu" do
    visit bookmarks_url

    actions = find("button[aria-label='Bookmark actions: Why Does God Allow Suffering?']")
    assert_operator actions.evaluate_script("this.offsetWidth"), :>=, 44, "the ⋯ button is too small to tap"
    assert_operator actions.evaluate_script("this.offsetHeight"), :>=, 44, "the ⋯ button is too small to tap"
    actions.click
    find("[role=menuitem]", text: "Edit").click

    within("dialog[open]") do
      assert_selector "h1", text: "Edit bookmark"
      fill_in "Comment", with: "The video at the end helps."
      wait_for_transitions # the menu closing and the Dialog opening fade the buttons' colours
      assert_accessible
      click_on "Save"
    end

    assert_no_selector "dialog[open]"
    within(row(@article)) { assert_text "jw.org · Quick references · #ministry" }
    assert_equal "The video at the end helps.", @article.reload.comment
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
  end

  test "remove a bookmark from its ⋯ menu" do
    visit bookmarks_url

    find("button[aria-label='Bookmark actions: Psalm 23:4']").click
    find("[role=menuitem]", text: "Remove").click

    assert_no_selector "main .Box-row", text: "Psalm 23:4"
    assert_selector "main .Box-row", count: 1
    assert_not Bookmark.exists?(@psalm.id)
  end

  test "bookmark buttons on a note and a study are 44px targets" do
    note = personal_notes(:head_return_visit)
    note.body = "<p>Then read Psalm 83:18.</p>"
    note.link_scriptures
    note.save!
    personal_study_question(personal_studies(:head_suffering), status: "answered",
      sources: [ { "url" => "https://www.jw.org/en/library/books/bible-questions-answered/", "title" => "Bible Questions Answered" } ],
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering (James 1:13)." ], "next_questions" => [] })

    visit household_personal_note_url(household_id: households(:home), id: note)
    within("section[aria-labelledby=note-scriptures]") { assert_tap_target find("button[aria-label='Bookmark: Psalm 83:18']") }
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")

    visit household_personal_study_url(household_id: households(:home), id: personal_studies(:head_suffering))
    find("[role=tab]", text: "Sources").click
    within("section[aria-labelledby=study-scriptures]") { assert_tap_target find("button[aria-label='Bookmark: James 1:13']") }
    within("section[aria-labelledby=study-sources]") do
      assert_tap_target find("button[aria-label='Bookmark: Bible Questions Answered']")
      find("button[aria-label='Bookmark: Bible Questions Answered']").click
      assert_tap_target find("button[aria-label='Remove bookmark: Bible Questions Answered']")
    end
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
  end

  private
    def bookmarks_url
      household_bookmarks_url(household_id: households(:home))
    end

    def row(bookmark)
      find("main ##{ActionView::RecordIdentifier.dom_id(bookmark)}")
    end

    def assert_tap_target(button)
      assert_operator button.evaluate_script("this.offsetWidth"), :>=, 44, "#{button[:"aria-label"]} is too small to tap"
      assert_operator button.evaluate_script("this.offsetHeight"), :>=, 44, "#{button[:"aria-label"]} is too small to tap"
    end
end
