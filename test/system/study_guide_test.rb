require "application_system_test_case"

# This week's study guide for Hannah, a head with it on (docs/design/study-guide.md, How it looks, Pages and routes;
# frames desktop-guide-midweek.png, desktop-guide-weekend.png and phone-guide.png). It's Tuesday 17 November 2026.
class StudyGuidePageTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 17, 16)
    @home = households(:home)
    @head = users(:head)
    User::WeeklyStudyGuide.create!(user: @head)
    @guide = @head.study_guides.create!(week_of: "2026-11-16")
    @guide.sources.create!(position: 1, title: "Life and Ministry Meeting Workbook, November 16-22", url: "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47")
  end

  test "from the sidebar to this week's guide, midweek then weekend, part by part" do
    add_midweek
    add_weekend
    sign_in identities(:head)
    visit household_root_url(household_id: @home)

    within("nav[aria-label='Main']") { click_link "Study guide" }

    assert_selector "h1", text: "Study guide"
    assert_text "Week of November 16–22, 2026 · Lamentations 1–2 · Only you see this."
    assert_selector ".SegmentedControl a[aria-current='true']", text: "Midweek"
    assert_link "My meeting notes"
    assert_text "AI wrote this from this week's program on jw.org, in its own words, with links. Check each point against its page."
    assert_text "This week at a glance"
    assert_text "Jeremiah grieves over Jerusalem."
    within(".study-guide-jehovah") do
      assert_selector "h2", text: "What this week's program teaches us about Jehovah"
      assert_text "Merciful"
      assert_text "He still hears his people."
    end

    within(".study-guide-part", text: "Keep Hoping in Jehovah") do
      assert_text "Treasures From God's Word · 10 min."
      assert_selector "dt", text: "Main points"
      assert_selector "dd li", text: "Honest prayer helps."
      assert_selector "dt", text: "About Jehovah"
    end
    within(".study-guide-part", text: "Ideas for comments") { assert_selector "dt", text: "Comment ideas" }
    within(".study-guide-part", text: "The Bible reading") do
      assert_text "Bible Reading · Lamentations 1–2"
      %w[ What\ happens What\ it\ teaches\ about\ Jehovah How\ we\ can\ apply\ it ].each { assert_selector "dt", text: it }
    end
    within(".study-guide-part", text: "Jehovah Is Near") do
      assert_selector "dd li", text: "¶1–3: Everyone faces loss."
      assert_selector "dd li", text: "¶5: I can lean on him."
    end

    # A verse, and a whole chapter, each a scripture link from its parsed reference; the AI's markup is text.
    assert_link "Lamentations 1:1", href: Bible::Reference.parse("Lamentations 1:1").jw_url
    assert_link "Psalm 23", href: Bible::Reference.parse("Psalm 23").jw_url
    assert_text "Talk about <b>hope</b>."
    assert_no_selector ".study-guide-part b"
    within(".study-guide-page__side") do
      assert_link "Life and Ministry Meeting Workbook, November 16-22"
      assert_text "wol.jw.org"
      within("section", text: "Scriptures in this guide") { assert_link "Psalm 23" }
    end
    assert_no_text "Some parts aren't ready yet."
    assert_button "Print"
    assert_accessible
    capture_screens("study-guide-midweek")

    click_link "Weekend"

    assert_selector ".SegmentedControl a[aria-current='true']", text: "Weekend"
    assert_text "Week of November 16–22, 2026 · Watchtower Study · Only you see this."
    assert_selector "h2", text: "What this study teaches us about Jehovah"
    within(".study-guide-part", text: "Watchtower Study · 60 min.") { assert_selector "h2", text: "Be Patient at Home" }
    assert_no_text "Keep Hoping in Jehovah"
    assert_accessible
    capture_screens("study-guide-weekend")
  end

  test "printed, the guide alone, with the pages it used and their full addresses at the end" do
    add_midweek
    sign_in identities(:head)
    visit household_study_guide_url(household_id: @home, week_of: "2026-11-16")
    assert_selector "aside", text: "Study guide"
    assert_no_text "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47"

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")

    assert_no_selector "aside"
    assert_no_selector ".study-guide-page__side"
    assert_no_button "Print"
    assert_no_text "Kept for 8 weeks."
    assert_no_link "My meeting notes"
    assert_selector "h2", text: "Keep Hoping in Jehovah"
    within(".study-guide-print-sources") do
      assert_selector "h2", text: "Pages used"
      assert_selector "li", text: "Life and Ministry Meeting Workbook, November 16-22 https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47"
    end
    # Emulated print fires no beforeprint, so the print controller's light colours aren't in this one.
    page.save_screenshot(Rails.root.join("tmp/screenshots/ui/study-guide-print.png")) if ENV["SCREENSHOTS"]
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  test "some parts missing: the parts it has, and the line saying the rest will be added" do
    add_part "talk", "title" => "Keep Hoping in Jehovah", "summary" => "The talk is about hope."
    sign_in identities(:head)
    visit household_study_guide_url(household_id: @home, week_of: "2026-11-16")

    assert_selector "h2", text: "Keep Hoping in Jehovah"
    assert_text "Some parts aren't ready yet. They'll be added when they are."
    assert_accessible
    capture_screens("study-guide-missing-parts")
  end

  test "the children's Get ready card on the Treasures part, for both children, and Change opens Get ready's dialog" do
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @home.enable_meeting_helper(by: @head)
    @home.enable_meeting_prep(by: @head)
    users(:child).create_identity!(username: "charlie", password: "password123", confirmed_at: Time.current)
    card = @home.prep_weeks.create!(week_of: "2026-11-16").cards.create!(
      meeting: "midweek", step: "talk", about: "Jeremiah felt very sad. But he remembered that Jehovah never stops caring.",
      quality: "caring", quality_line: "His kindness is new every morning.", i_can: "Tell Jehovah when I feel sad.")
    add_midweek
    sign_in identities(:head)
    visit household_study_guide_url(household_id: @home, week_of: "2026-11-16")

    within(".study-guide-part", text: "Keep Hoping in Jehovah") do
      within(".study-guide-prep-card") do
        assert_text "For Charlie and Eli · from Get ready"
        assert_text "Jeremiah felt very sad. But he remembered that Jehovah never stops caring."
        assert_text "Jehovah cares · I can Tell Jehovah when I feel sad."
      end
    end
    within(".study-guide-part", text: "Ideas for comments") { assert_no_selector ".study-guide-prep-card" }
    within(".study-guide-part", text: "Comfort Those Who Mourn") { assert_no_selector ".study-guide-prep-card" }
    assert_accessible
    capture_screens("study-guide-prep-card", scroll_to: ".study-guide-prep-card")

    within(".study-guide-prep-card") { click_on "Change" }

    assert_selector "dialog[open] h1", text: "Treasures From God's Word"
    assert_field "I can…", with: "Tell Jehovah when I feel sad."
    wait_for_dialog
    assert_accessible

    fill_in "I can…", with: "Draw Jehovah a <b>thank-you</b> picture."
    click_on "Save"

    assert_no_selector "dialog[open]"
    assert_text "Card saved."
    within(".study-guide-part", text: "Keep Hoping in Jehovah") do
      assert_selector ".study-guide-prep-card", text: "Jehovah cares · I can Draw Jehovah a <b>thank-you</b> picture."
    end
    assert_equal "Draw Jehovah a <b>thank-you</b> picture.", card.reload.i_can
    assert_accessible
  end

  private
    def add_part(step, content)
      @guide.parts.create!(step:, content:)
    end

    def add_midweek
      add_part "midweek_overview", "glance" => "Jeremiah grieves over Jerusalem.",
        "jehovah" => [ { "quality" => "Merciful", "text" => "He still hears his people.", "ref" => "Lamentations 1:20" } ]
      add_part "talk", "title" => "Keep Hoping in Jehovah", "summary" => "Talk about <b>hope</b>.",
        "points" => [ { "text" => "Jerusalem's fall wasn't the end.", "ref" => "Lamentations 1:1" }, { "text" => "Honest prayer helps." } ],
        "jehovah" => [ { "text" => "He cares for the hurt.", "ref" => "Psalm 23" } ]
      add_part "spiritual_gems", "summary" => "Short comments you could give.",
        "comments" => [ { "text" => "Jeremiah spoke honestly.", "ref" => "Lamentations 2:11" }, { "text" => "Jehovah makes room for grief." } ]
      add_part "bible_reading", "reading" => "Lamentations 1–2", "summary" => "Jeremiah mourns Jerusalem.",
        "happens" => [ { "text" => "Jerusalem lies empty." } ], "teaches" => [ { "text" => "He keeps his word." } ],
        "apply" => [ { "text" => "Tell Jehovah how we feel." } ]
      add_part "field_ministry", "title" => "Start Conversations With Kindness", "summary" => "A warm question opens a talk.",
        "apply" => [ { "text" => "Ask a neighbor how they are." } ]
      add_part "living", "title" => "Comfort Those Who Mourn", "summary" => "Notice who is grieving.",
        "apply" => [ { "text" => "Send a card." } ]
      add_part "congregation_bible_study", "title" => "Jehovah Is Near", "summary" => "Jehovah supports the crushed.",
        "notes" => [ { "paragraphs" => "1–3", "text" => "Everyone faces loss." } ],
        "comments" => [ { "paragraph" => "5", "text" => "I can lean on him." } ]
    end

    def add_weekend
      add_part "weekend_overview", "glance" => "Patience at home.",
        "jehovah" => [ { "quality" => "Patient", "text" => "He gives people time to change." } ]
      add_part "watchtower_study", "title" => "Be Patient at Home", "summary" => "The article is about patience.",
        "notes" => [ { "paragraphs" => "1–4", "text" => "Patience takes practice.", "ref" => "Proverbs 17:17" } ]
    end
end
