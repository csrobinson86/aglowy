require "application_system_test_case"
require_relative "../support/study_answer_helper"

# A study on a phone (docs/design/personal-study.md, Pages and routes; frame phone-personal-study.png): Conversation,
# Notes and Sources as tabs, the tag editor and actions in the "…" menu, and the ask box at the bottom. answer runs
# the question's job with the AI stubbed (StudyAnswerHelper), so nothing calls an AI provider.
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
    assert_selector "[role=tab][aria-selected=true]", exact_text: "Note"
    within("section[aria-labelledby=study-note]") do
      assert_text "No note yet. Save an answer to start one, or write your own."
      assert_button "Start a note"
    end
    assert_no_selector "section[aria-labelledby=study-conversation]"

    find("[role=tab]", exact_text: "Note").send_keys(:right)
    assert_selector "[role=tab][aria-selected=true]", text: "Sources"
    assert_selector "section[aria-labelledby=study-sources]"

    find("[role=tab]", text: "Sources").send_keys(:left)
    assert_selector "[role=tab][aria-selected=true]", exact_text: "Note"
    assert_selector "section[aria-labelledby=study-note]"
  end

  test "\"See sources\" opens Sources" do
    personal_study_question(@study, status: "answered", sources: [ { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" } ],
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering (James 1:13)." ], "next_questions" => [] })
    visit study_url

    within(question_card("Why does Jehovah allow suffering?")) do
      assert_text "1 page used"
      assert_no_selector "ul[aria-label='Pages used']"
      click_on "See sources"
    end

    assert_selector "[role=tab][aria-selected=true]", text: "Sources"
    assert_no_selector "section[aria-labelledby=study-conversation]"
    within("section[aria-labelledby=study-sources]") { assert_link "Why Does God Allow Suffering?" }
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
        assert_text "3 pages used"
        assert_button "See sources"
      end
    end
    assert_text "jw.org and wol.jw.org only · 29 of 30 left today"
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
    capture_screens("phone-personal-study")
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

  test "the header keeps a back link and the title, and the tag editor and actions are in the \"…\" menu" do
    visit study_url

    assert_selector "h1", text: "Why does Jehovah allow suffering?"
    assert_link "Back to Bible questions", href: household_personal_studies_path(household_id: households(:home), collection: collections(:head_bible_questions).id)
    assert_no_selector "nav[aria-label=Breadcrumb]"
    assert_no_field "Add a tag"
    assert_no_link "Plan a family study from this"

    find("button[aria-label='Study actions']").click
    assert_selector "[role=menuitem]", text: "Plan a family study from this"
    find("[role=menuitem]", text: "Tags…").click
    within("dialog", text: "Tags") do
      fill_in "Add a tag", with: "comfort"
      find_field("Add a tag").send_keys(:enter)
      assert_link "#comfort"
    end
    assert_equal [ "comfort" ], @study.tags_for(users(:head)).pluck(:name)
    assert_accessible
  end

  test "the studies list puts collections and tags above the list, behind a disclosure" do
    visit household_personal_studies_url(household_id: households(:home))

    assert_no_link "All studies"
    find("summary", text: "Collections and tags").click
    assert_link "All studies"
    assert_operator find_link("All studies").evaluate_script("this.getBoundingClientRect().top"), :<,
      find_link("Why does Jehovah allow suffering?").evaluate_script("this.getBoundingClientRect().top")
    assert_accessible
    capture_screens("phone-personal-studies")
  end

  private
    def study_url
      household_personal_study_url(household_id: households(:home), id: @study)
    end
end
