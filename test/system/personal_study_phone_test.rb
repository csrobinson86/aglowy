require "application_system_test_case"
require_relative "../support/study_answer_helper"

# A study on a phone (docs/design/personal-study.md, Pages and routes; docs/design/phone.md, A personal study; frame
# phone-personal-study.png): the back row with the study's "…", the title and one meta line, Conversation, Notes and
# Sources as tabs, each answer's pages folded behind "N pages used", and the ask box at the bottom. The list has
# "+ New ▾" beside its title. answer runs the question's job with the AI stubbed (StudyAnswerHelper), so nothing calls
# an AI provider.
class PersonalStudyPhoneTest < ApplicationSystemTestCase
  include StudyAnswerHelper

  setup do
    users(:head).accept_ai_terms(understood: "1")
    sign_in identities(:head)
    @study = personal_studies(:head_suffering)
    visit root_url
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
    emulate_touch(true)
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "tabs switch with the arrow keys" do
    visit study_url

    assert_selector "[role=tab][aria-selected=true]", text: "Conversation"
    assert_selector "section[aria-labelledby=study-conversation]"
    assert_no_selector "section[aria-labelledby=study-note]"

    find("[role=tab]", text: "Conversation").send_keys(:right)
    assert_selector "[role=tab][aria-selected=true]", text: "Notes"
    assert_selector "section[aria-labelledby=study-note]"
    assert_no_selector "section[aria-labelledby=study-conversation]"

    find("[role=tab]", text: "Notes").send_keys(:right)
    assert_selector "[role=tab][aria-selected=true]", text: "Sources"
    assert_selector "section[aria-labelledby=study-sources]"

    find("[role=tab]", text: "Sources").send_keys(:left)
    assert_selector "[role=tab][aria-selected=true]", text: "Notes"
    assert_selector "section[aria-labelledby=study-note]"
  end

  test "the back row has the link to the study's collection and the \"…\", then the title at full width and the meta line" do
    personal_study_question(@study, status: "answered", sources: ten_pages, answer: noah_answer)
    visit study_url

    back = find("a", text: "Bible questions")
    assert_equal household_personal_studies_path(household_id: households(:home), collection: collections(:head_bible_questions).id), URI(back[:href]).request_uri
    assert_no_selector "nav[aria-label=Breadcrumb]"
    menu_button = find("button[aria-label='Study actions']")
    assert_in_delta back.evaluate_script("this.getBoundingClientRect().top + this.offsetHeight / 2"),
      menu_button.evaluate_script("this.getBoundingClientRect().top + this.offsetHeight / 2"), 2, "the \"…\" isn't on the back row"
    assert_touch_target back
    assert_touch_target menu_button
    assert_empty menu_button[:class].split & %w[ Button--secondary ], "the \"…\" isn't a plain icon"

    heading = find("main h1", text: "Why does Jehovah allow suffering?")
    assert_operator heading.evaluate_script("this.getBoundingClientRect().top"), :>, menu_button.evaluate_script("this.getBoundingClientRect().bottom"), "the title isn't under the back row"
    assert_operator heading.evaluate_script("this.getBoundingClientRect().width"), :>=, find("main .personal-study-tabs").evaluate_script("this.getBoundingClientRect().width") - 1, "the title isn't full width"
    meta = find("p, div", exact_text: "Started #{I18n.l(@study.created_at.to_date, format: :long)} · 1 question · 10 pages linked")
    assert_operator meta.evaluate_script("this.getBoundingClientRect().top"), :>=, heading.evaluate_script("this.getBoundingClientRect().bottom")
    assert_no_field "Add a tag"
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
  end

  test "the back row goes to Personal study for a study in no collection" do
    visit household_personal_study_url(household_id: households(:home), id: personal_studies(:head_daniel))

    assert_equal household_personal_studies_path(household_id: households(:home)), URI(find("a", exact_text: "Personal study")[:href]).request_uri
  end

  test "the \"…\" lists today's items, each big enough to touch" do
    visit study_url
    assert_turbo_idle

    find("button[aria-label='Study actions']").click
    assert_selector "[role=menuitem]", text: "Create family study"
    wait_for_animations
    assert_equal [ "Create family study", "—", "Tags…", "Rename…", "Move to collection…", "—", "Delete study…" ], menu_entries("personal-study-phone-menu")
    all("[role=menuitem]").each { assert_touch_target it }
    assert_accessible
    capture_screens("phone-personal-study-menu", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "Tags… in the \"…\" opens the tag editor" do
    visit study_url
    assert_turbo_idle

    find("button[aria-label='Study actions']").click
    find("[role=menuitem]", text: "Tags…").click
    within("dialog", text: "Tags") do
      fill_in "Add a tag", with: "comfort"
      find_field("Add a tag").send_keys(:enter)
      assert_link "#comfort"
    end
    assert_equal [ "comfort" ], @study.tags_for(users(:head)).pluck(:name)
  end

  test "Rename from the \"…\" renames the study" do
    visit study_url

    assert_turbo_idle
    find("button[aria-label='Study actions']").click
    find("[role=menuitem]", text: "Rename…").click
    wait_for_dialog
    within("dialog[open]", text: "Rename study") do
      fill_in "Title", with: "Why God allows suffering"
      click_on "Rename"
    end

    assert_selector "main h1", text: "Why God allows suffering"
  end

  test "an answer's pages are behind \"10 pages used\" and open on tap, and the page matches the frame" do
    personal_study_question(@study, status: "answered", sources: ten_pages, answer: noah_answer)
    visit study_url

    within(question_card("Why does Jehovah allow suffering?")) do
      summary = find("summary", text: "10 pages used")
      assert_selector "summary svg.octicon-chevron-right"
      assert_touch_target summary
      assert_no_selector "ul[aria-label='Pages used']"
      assert_button "Save to note"

      summary.click
      assert_selector "ul[aria-label='Pages used'] li", count: 10
      assert_link "Noah — He Walked With God"
      assert_equal "true", summary[:"aria-expanded"]
    end
    assert_accessible

    # Phone only: the desktop shot would open the pages first (open-from-md), and they'd stay open on the phone shot.
    visit study_url
    capture_screens("phone-personal-study", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "from md up an answer's pages show open, with no summary" do
    personal_study_question(@study, status: "answered", sources: ten_pages, answer: noah_answer)
    cdp("Emulation.clearDeviceMetricsOverride")
    emulate_touch(false)
    visit study_url

    within(question_card("Why does Jehovah allow suffering?")) do
      assert_selector "h3", text: "Pages used"
      assert_selector "ul[aria-label='Pages used'] li", count: 10
      assert_no_selector "summary", text: "pages used"
    end
    capture_screens("personal-study-pages-used", viewports: ScreenshotHelper::VIEWPORTS.slice(:desktop))
  end

  test "asking (stubbed) shows the answer in Conversation" do
    visit study_url

    within("#study-ask") do
      assert_text "jw.org and wol.jw.org only · 30 of 30 left today"
      [ find_field("Ask a question"), find_button("Ask") ].each do |control|
        assert_operator control.evaluate_script("this.offsetHeight"), :>=, 44, "#{control[:name]} is too small to tap"
      end
    end
    assert_in_delta evaluate_script("window.innerHeight"), find("#study-ask").evaluate_script("this.getBoundingClientRect().bottom"), 1, "the ask box isn't at the bottom"

    fill_in "Ask a question", with: "Why does Jehovah allow suffering, and will it ever end?"
    click_on "Ask"
    within(question_card("Why does Jehovah allow suffering, and will it ever end?")) do
      assert_selector "ul[aria-live=polite] li", text: "Searching jw.org and wol.jw.org…"
    end
    assert_selector "turbo-cable-stream-source[data-study-ask-target='stream'][connected]", visible: :all

    answer("personal_study_answer")

    assert_selector "[role=tab][aria-selected=true]", text: "Conversation"
    within("section[aria-labelledby=study-conversation]") do
      within(question_card("Why does Jehovah allow suffering, and will it ever end?")) do
        assert_button "Save to note"
        assert_text "The publications explain that suffering didn't start with God."
        assert_link "Genesis 3:1-6"
        assert_selector "summary", text: "3 pages used"
        assert_no_selector "ul[aria-label='Pages used']"
      end
    end
    assert_text "jw.org and wol.jw.org only · 29 of 30 left today"
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
  end

  test "the ask box stays at the bottom of the screen, on the page's background, after scrolling a long conversation" do
    6.times do |index|
      personal_study_question(@study, prompt: "Question #{index + 1}", status: "answered", sources: ten_pages, answer: noah_answer)
    end
    visit study_url

    first, third = question_card("Question 1"), question_card("Question 3")
    third.evaluate_script("this.scrollIntoView({ block: 'start', behavior: 'instant' })")
    assert_operator first.evaluate_script("this.getBoundingClientRect().bottom"), :<, 0, "the conversation didn't scroll"

    ask = find("#study-ask")
    assert_in_delta evaluate_script("window.innerHeight"), ask.evaluate_script("this.getBoundingClientRect().bottom"), 1, "the ask box isn't at the bottom"
    assert ask.find_field("Ask a follow-up").visible?
    assert_equal "sticky", ask.evaluate_script("getComputedStyle(this).position")
    assert_equal computed_color("var(--bgColor-default)"), background_color("#study-ask")
  end

  test "without the AI terms, the first-use notice stays in the page, with its checkbox labelled" do
    users(:head).ai_acceptances.delete_all
    visit study_url

    assert_selector "h2", text: "Before you use AI"
    assert_no_selector "#study-ask.study-ask"
    check "I understand how AI drafts work"
    click_on "Turn on AI drafts"
    assert_field "Ask a question"
  end

  test "the list's title row has + New ▾ beside the title, and New › Study opens New study" do
    visit studies_url

    heading = find("main h1", text: "Personal study")
    new_button = find("button", exact_text: "New")
    assert_operator new_button.evaluate_script("this.getBoundingClientRect().top"), :<, heading.evaluate_script("this.getBoundingClientRect().bottom"), "New isn't beside the title"
    assert_operator new_button.evaluate_script("this.getBoundingClientRect().right"), :<=, evaluate_script("document.documentElement.clientWidth")
    assert_operator new_button.evaluate_script("this.offsetHeight"), :>=, 44
    assert_no_link "New study"

    assert_turbo_idle
    new_button.click
    assert_equal [ "Study", "Collection" ], menu_entries("personal-studies-new-menu")
    all("#personal-studies-new-menu-list [role=menuitem]").each { assert_touch_target it }
    assert_accessible
    find("[role=menuitem]", exact_text: "Study").click

    assert_selector "h1", text: "New study"
  end

  test "New › Collection opens the New collection dialog" do
    visit studies_url

    choose_from_menu "New", "Collection"
    wait_for_dialog
    within("dialog[open]", text: "New collection") do
      fill_in "Name", with: "Convention 2027"
      assert_accessible
      click_on "Create collection"
    end

    assert_text "Collection created."
    assert_selector "h2", text: "Convention 2027"
  end

  test "\"Only you can see these.\" shows for studies nobody else reads" do
    visit studies_url

    assert_text "Only you can see these."
    assert_no_text "Your own research, with notes, collections and tags."
    assert_accessible
    capture_screens("phone-personal-studies")
  end

  test "\"Only you can see these.\" doesn't show for a child's studies heads can read" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))
    sign_out :identity
    sign_in identities(:eli)
    visit studies_url

    assert_selector ".Banner", text: "Your parents can read your personal study"
    assert_no_text "Only you can see these."
    assert_no_text "Only you can see it."
  end

  test "the studies list puts collections and tags above the list, behind a disclosure" do
    visit studies_url

    assert_no_link "All studies"
    find("summary", text: "Collections and tags").click
    assert_link "All studies"
    assert_operator find_link("All studies").evaluate_script("this.getBoundingClientRect().top"), :<,
      find_link("Why does Jehovah allow suffering?").evaluate_script("this.getBoundingClientRect().top")
    assert_accessible
  end

  private
    def study_url
      household_personal_study_url(household_id: households(:home), id: @study)
    end

    def studies_url
      household_personal_studies_url(household_id: households(:home))
    end

    # Ten pages, as an answer about Noah lists in the frame.
    def ten_pages
      [ { "url" => "https://www.jw.org/en/library/books/imitate-their-faith/noah/", "title" => "Noah — He Walked With God" },
        *(1..9).map { { "url" => "https://wol.jw.org/en/wol/d/r1/lp-e/#{it}", "title" => "Faith in action, part #{it}" } } ]
    end

    def noah_answer
      { "not_found" => false, "not_found_note" => "", "next_questions" => [],
        "paragraphs" => [ "Noah kept building for decades while people around him ignored the warning (Genesis 6:22). His faith showed in what he did, day after day, not only in what he believed.",
                          "He also kept preaching, so his family heard the same message they saw him live (Hebrews 11:7; 2 Peter 2:5)." ] }
    end
end
