require "application_system_test_case"

# Family studies on a phone (docs/design/phone.md, Family studies; frames phone-family-studies.png and
# phone-family-study-session.png; story #416): the list opens with a Next card and one row per coming session, and a
# session has the back row with its "…", the h1, one meta line, a plain Edit on Notes and resources as rows. Desktop
# doesn't change.
class FamilyStudiesPhoneTest < ApplicationSystemTestCase
  setup do
    @next = family_study_sessions(:weekly_next)
    @next.update!(topic: "Proverbs 3")
  end

  teardown do
    on_desktop
  end

  test "the Next card names the next session and opens it" do
    sign_in identities(:head)
    visit_on_a_phone household_family_studies_url(household_id: households(:home))

    card = find("a.family-studies-next")
    assert_equal [ "Next", "Proverbs 3", "#{@next.local_scheduled_at.strftime("%A, %b %-d")} · 7:00 PM · #{@next.family_study.repeat_description}" ],
      card.all(":scope > span").map { it.text.squish }
    assert_touch_target card

    card.click
    assert_selector "main h1", exact_text: "Proverbs 3"
  end

  test "each coming session row has its month and day, its topic and its weekday and time, and ›" do
    sign_in identities(:head)
    visit_on_a_phone household_family_studies_url(household_id: households(:home))

    assert_selector "h2", exact_text: "Coming up"
    rows = all(".family-study-row", count: 3)
    [ family_study_sessions(:one_off_first), family_study_sessions(:weekly_cancelled), family_study_sessions(:weekly_later) ].zip(rows).each do |study_session, row|
      local = study_session.local_scheduled_at
      assert_equal local.strftime("%b"), row.find(".family-study-row__month").text(normalize_ws: true).capitalize
      assert_equal local.day.to_s, row.find(".family-study-row__day").text
      assert_equal "#{local.strftime("%A")} · 7:00 PM#{" · Cancelled" if study_session.canceled?}", row.find(".family-study-row__when").text.squish
      assert_selector ".family-study-row svg.octicon-chevron-right"
      assert_equal household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session), URI(row[:href]).path
      assert_touch_target row
    end
    assert_equal "Draw Close to Jehovah, chapter 1", rows.first.find(".family-study-row__topic").text
    assert_no_selector ".family-study-row .Label"
    assert_no_selector "nav[aria-label='Breadcrumb']"
    assert_equal page.evaluate_script("document.documentElement.clientWidth"), page.evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
    capture_screens("phone-family-studies")
  end

  test "a topic-less session reads Topic not chosen yet, muted" do
    sign_in identities(:head)
    visit_on_a_phone household_family_studies_url(household_id: households(:home))

    topic = find(".family-study-row[href$='/#{family_study_sessions(:weekly_later).id}'] .family-study-row__topic")
    assert_equal "Topic not chosen yet", topic.text
    assert_includes topic[:class], "color-fg-muted"

    @next.update!(topic: nil)
    visit_on_a_phone household_family_studies_url(household_id: households(:home))
    assert_selector "a.family-studies-next .color-fg-muted", exact_text: "Topic not chosen yet"
  end

  test "a session: the back row to Family studies with its …, the h1 under it and the meta line" do
    add_notes_and_resources
    sign_in identities(:head)
    visit_on_a_phone session_url(@next)

    back = find(".back-row a", exact_text: "Family studies")
    assert_equal household_family_studies_path(household_id: households(:home)), URI(back[:href]).path
    menu_button = find("button[aria-label='Session actions']")
    assert_touch_target back
    assert_touch_target menu_button
    assert_no_selector "nav[aria-label='Breadcrumb']"
    assert_no_link "Edit this session"
    assert_no_button "Cancel this session"

    h1 = find("main h1", exact_text: "Proverbs 3")
    assert_operator h1.evaluate_script("this.getBoundingClientRect().top"), :>=, back.evaluate_script("this.getBoundingClientRect().bottom")
    local = @next.local_scheduled_at
    assert_selector "#session-meta", exact_text: "#{local.strftime("%A, %B %-d, %Y")} · 7:00 – 7:45 PM · #{@next.family_study.repeat_description}"
    assert_no_selector ".Label", text: "Cancelled"

    resource = find(".Box-row", text: "Article on trusting Jehovah")
    title, host = resource.find("a", exact_text: "Article on trusting Jehovah"), resource.find("span", exact_text: "wol.jw.org")
    assert_operator host.evaluate_script("this.getBoundingClientRect().top"), :>=, title.evaluate_script("this.getBoundingClientRect().bottom") - 1, "the host isn't on its own line"
    assert_equal page.evaluate_script("document.documentElement.clientWidth"), page.evaluate_script("document.documentElement.scrollWidth")
    assert_accessible

    find("button[aria-label='Session actions']").click
    wait_for_animations
    assert_equal [ "Edit session", "—", "Cancel this session…" ], menu_entries("session-phone-menu")
    all("#session-phone-menu-list [role=menuitem]").each { assert_touch_target it }
    assert_accessible
    capture_screens("phone-family-study-session-menu", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))

    visit_on_a_phone session_url(@next)
    capture_screens("phone-family-study-session")
  end

  test "a long resource title and a long topic stay on one line, cut with an ellipsis, so their rows stay two lines" do
    long = "Imitate Their Faith: Ruth, Naomi and the loyal love that carried two widows home to Bethlehem"
    family_study_sessions(:weekly_later).update!(topic: long)
    @next.resources.create!(kind: :link, url: "https://wol.jw.org/en/wol/d/r1/lp-e/2023361", title: long)
    sign_in identities(:head)

    visit_on_a_phone household_family_studies_url(household_id: households(:home))
    assert_cut_to_one_line find(".family-study-row__topic", exact_text: long)

    visit_on_a_phone session_url(@next)
    title = find(".family-study-session__resource-title", exact_text: long)
    assert_cut_to_one_line title
    host = find(".Box-row", text: long).find("span", exact_text: "wol.jw.org")
    assert_operator host.evaluate_script("this.getBoundingClientRect().top"), :>=, title.evaluate_script("this.getBoundingClientRect().bottom") - 1
    assert_equal page.evaluate_script("document.documentElement.clientWidth"), page.evaluate_script("document.documentElement.scrollWidth")
  end

  test "Edit session in the … opens the edit page" do
    sign_in identities(:head)
    visit_on_a_phone session_url(@next)

    choose_from_session_menu "Edit session"
    assert_selector "h1", text: "Edit this session"
  end

  test "Cancel this session… asks first, then the meta line says Cancelled, and Restore this session restores it" do
    sign_in identities(:spouse)
    visit_on_a_phone session_url(@next)

    choose_from_session_menu "Cancel this session…"
    wait_for_dialog
    within("dialog[open]") do
      assert_selector "h1", text: "Cancel this session?"
      assert_accessible
      click_on "Cancel this session"
    end

    assert_selector "#session-meta .color-fg-danger", exact_text: "Cancelled"
    assert @next.reload.canceled?
    find("button[aria-label='Session actions']").click
    wait_for_animations
    assert_equal [ "Edit session", "—", "Restore this session" ], menu_entries("session-phone-menu")
    find("[role=menuitem]", exact_text: "Restore this session").click

    assert_no_selector "#session-meta .color-fg-danger"
    assert_not @next.reload.canceled?
  end

  test "a child sees the back row without a …" do
    sign_in identities(:eli)
    visit_on_a_phone session_url(@next)

    assert_selector ".back-row a", exact_text: "Family studies"
    assert_no_selector ".back-row__menu"
    assert_no_selector "button[aria-label='Session actions']"
    assert_no_link "Edit"
    assert_accessible
  end

  test "Notes' plain Edit link opens the notes editor" do
    sign_in identities(:head)
    visit_on_a_phone session_url(@next)

    edit = find(".Box-header a", exact_text: "Edit")
    assert_selector ".Box-header a svg.octicon-pencil"
    assert_no_selector ".Box-header .Button", text: "Edit notes"
    assert_touch_target edit

    edit.click
    assert_selector "h1", text: "Edit notes"
  end

  test "from md up the list and a session are as before" do
    sign_in identities(:head)
    visit household_family_studies_url(household_id: households(:home))

    assert_no_selector ".family-studies-next"
    assert_no_selector ".family-study-row"
    assert_selector ".Box-header h2", exact_text: "Coming up"
    assert_selector ".Box-row", count: 4
    assert_link "Schedule a study"

    visit session_url(family_study_sessions(:weekly_cancelled))
    assert_selector "nav[aria-label='Breadcrumb']"
    assert_no_selector ".back-row"
    assert_link "Edit this session"
    assert_button "Restore this session"
    assert_selector ".Subhead .Label", text: "Cancelled"
    assert_link "Edit notes"
    assert_no_selector ".Box-header a:not(.Button)", text: "Edit"

    visit session_url(@next)
    click_on "Cancel this session"
    wait_for_dialog
    within("dialog[open]") { click_on "Cancel this session" }
    assert_selector ".Subhead .Label", text: "Cancelled"
  end

  private
    def visit_on_a_phone(url)
      on_a_phone
      visit url
    end

    # Again after capture_screens, which leaves the desktop's viewport.
    def on_a_phone
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
    end

    def on_desktop
      cdp("Emulation.clearDeviceMetricsOverride")
      cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    end

    def session_url(study_session)
      household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end

    # Its text runs past its box, so it's cut, and the box is one line tall.
    def assert_cut_to_one_line(element)
      assert_operator element.evaluate_script("this.scrollWidth - this.clientWidth"), :>, 0, "the text fits, so nothing is cut"
      assert_equal element.evaluate_script("parseFloat(getComputedStyle(this).lineHeight)").round, element.evaluate_script("this.clientHeight")
    end

    # The menu's button is named only by its aria-label.
    def choose_from_session_menu(item)
      assert_turbo_idle
      find("button[aria-label='Session actions']").click
      find("[role=menuitem]", exact_text: item).click
    end

    # Frame phone-family-study-session.png's notes and article.
    def add_notes_and_resources
      @next.update!(notes: "<p>Trust Jehovah with all your heart. Each of us named one decision this week where we'll ask him first.</p>")
      @next.resources.create!(kind: :link, url: "https://wol.jw.org/en/wol/d/r1/lp-e/2023361", title: "Article on trusting Jehovah")
    end
end
