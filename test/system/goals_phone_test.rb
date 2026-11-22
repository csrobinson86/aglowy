require "application_system_test_case"

# A goal's header on a phone (docs/design/phone.md, The rules: 2 to 5, and A goal; frames phone-goal.png,
# phone-goal-menu.png and phone-goal-dark.png; story #410): a back row with the goal's "…" at its right end, the h1 at
# full width under it, one muted meta line, the why, and a personal goal's tags as chips. Desktop doesn't change.
class GoalsPhoneTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 14, 12)
    @goal = goals(:spouse_bible_reading)
    @goal.tag_with("faith", by: users(:spouse))
  end

  teardown do
    on_desktop
  end

  test "a personal goal: My goals and the … on one row, the h1 under it at full width, the meta line and the tag chip" do
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    back = find(".back-row a", exact_text: "My goals")
    assert_equal household_my_goals_path(household_id: households(:home)), URI(back[:href]).path
    menu_button = find("button[aria-label='Goal actions']")
    assert_in_delta center(back), center(menu_button), 2, "the back link and the … aren't on one row"
    assert_operator rect(menu_button, "right"), :>, rect(find("main h1"), "right") - 50, "the … isn't at the right end"
    assert_touch_target back
    assert_touch_target menu_button
    assert_no_selector "nav[aria-label='Breadcrumb']"

    h1 = find("main h1", exact_text: "Read the whole Bible in a year")
    assert_operator rect(h1, "top"), :>=, rect(back, "bottom")
    assert_in_delta rect(find(".back-row"), "width"), rect(h1, "width"), 1, "the h1 isn't at the full content width"

    assert_selector "#goal-meta", exact_text: "Private · Milestone · Target Jan 31, 2027"
    assert_selector "#goal-meta svg.octicon-lock"
    assert_no_selector ".Label", text: "Milestone"
    assert_no_selector ".Label", text: "Private"
    assert_no_field "Add a tag"
    assert_link "#faith", href: household_tag_path(household_id: households(:home), name: "faith")
    assert_touch_target find(".goal-header__tags a", exact_text: "#faith")
    assert_equal page.evaluate_script("document.documentElement.clientWidth"), page.evaluate_script("document.documentElement.scrollWidth")
    capture_screens("phone-goal")
  end

  test "Tags… opens the tag editor in a dialog, and the chips follow what it changes" do
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    choose_from_goal_menu "Tags…"
    wait_for_dialog
    within("dialog[open]") do
      assert_selector "h1", text: "Tags"
      assert_link "#faith"
      fill_in "Add a tag", with: "reading\n"
      assert_link "#reading"
    end
    assert_accessible
    find("dialog[open] button[aria-label='Close']").click

    assert_no_selector "dialog[open]"
    assert_link "#reading", href: household_tag_path(household_id: households(:home), name: "reading")
    assert_no_field "Add a tag"
  end

  test "the menu has its items in order, with Delete goal… last, and Delete goal… asks first" do
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    assert_turbo_idle
    find("button[aria-label='Goal actions']").click
    wait_for_animations
    assert_equal [ "Edit goal", "Share with household…", "Tags…", "—", "Mark goal complete", "Archive", "—", "Delete goal…" ], menu_entries("goal-phone-menu")
    all("#goal-phone-menu-list [role=menuitem]").each { assert_touch_target it }
    assert_accessible
    capture_screens("phone-goal-menu", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))

    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)
    choose_from_goal_menu "Delete goal…"
    wait_for_dialog
    within("dialog[open]") { assert_selector "h1", text: "Delete this goal?" }
  end

  test "Share with household… opens today's share dialog" do
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    choose_from_goal_menu "Share with household…"
    wait_for_dialog
    within("dialog[open]") { click_on "Share goal" }

    assert_text "Shared with The Head Family."
    assert_selector "#goal-meta", exact_text: "Shared with The Head Family · Milestone · Target Jan 31, 2027"
  end

  test "a shared goal: the owner's menu offers Stop sharing, and a member reading it sees whose it is" do
    @goal.share_with(households(:home))
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    assert_selector "#goal-meta", exact_text: "Shared with The Head Family · Milestone · Target Jan 31, 2027"
    choose_from_goal_menu "Stop sharing"
    assert_selector "#goal-meta", exact_text: "Private · Milestone · Target Jan 31, 2027"

    @goal.share_with(households(:home))
    sign_out :identity
    sign_in identities(:head)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    assert_selector ".back-row a", exact_text: "My goals"
    assert_selector "#goal-meta", exact_text: "Shared by Sam Spouse · Milestone · Target Jan 31, 2027"
    assert_selector "#goal-meta svg.octicon-people"
    assert_no_selector "button[aria-label='Goal actions']"
    assert_no_selector ".goal-header__tags"
  end

  test "a family goal's meta line names who set it" do
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: goals(:gospels))

    assert_selector ".back-row a", exact_text: "Family goals"
    assert_selector "#goal-meta", exact_text: "Milestone · Target Mar 31, 2027 · Set by Sam Spouse"
    assert_no_selector "#goal-meta svg"
    assert_selector "button[aria-label='Goal actions']"
  end

  test "a child sees the back row without a …" do
    sign_in identities(:eli)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: goals(:gospels))

    assert_selector ".back-row a", exact_text: "Family goals"
    assert_no_selector ".back-row__menu"
    assert_no_selector "button[aria-label='Goal actions']"
    assert_accessible
  end

  test "desktop still shows the breadcrumbs, Edit and Share, and no back row" do
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: @goal)

    assert_selector "nav[aria-label='Breadcrumb'] a", text: "My goals"
    assert_no_selector ".back-row"
    assert_no_selector "#goal-meta"
    assert_link "Edit"
    assert_button "Share with household"
    assert_selector "h1 .Label", text: "Milestone"
    assert_selector "h1 .Label", text: "Private"
    assert_text "Target January 31, 2027"
    assert_field "Add a tag"
    assert_no_selector ".goal-header__tags"
  end

  private
    def visit_on_a_phone(url)
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
      visit url
    end

    # The menu's button is named only by its aria-label.
    def choose_from_goal_menu(item)
      assert_turbo_idle
      find("button[aria-label='Goal actions']").click
      find("[role=menuitem]", exact_text: item).click
    end

    def on_desktop
      cdp("Emulation.clearDeviceMetricsOverride")
      cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    end

    def center(element)
      element.evaluate_script("(rect => rect.top + rect.height / 2)(this.getBoundingClientRect())")
    end

    def rect(element, side)
      element.evaluate_script("this.getBoundingClientRect().#{side}")
    end
end
