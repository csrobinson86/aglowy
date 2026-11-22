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

  test "tag chips that wrap onto several rows, one-letter ones too, each keep a whole 44px target of their own" do
    %w[a b study-together family-worship prayer c memorization ministry].each { @goal.tag_with(it, by: users(:spouse)) }
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    chips = all(".goal-header__tags a", count: 9)
    assert_operator chips.map { rect(it, "top") }.uniq.size, :>, 1, "the chips don't wrap"
    chips.each { assert_touch_target it }
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

  # Story #411: the progress card, step rows and "+ Add step" (frames phone-goal.png, phone-goal-add-step.png and
  # phone-family-goal.png).
  test "a personal goal: the progress card's three lines, each row's second line, and no pencils" do
    add_bible_reading_steps
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    within("#goal-progress-card") do
      assert_selector "h2", exact_text: "1 of 2 steps done"
      assert_selector ".goal-progress-card__percent", exact_text: "50%"
      assert_selector ".Progress"
      assert_selector ".goal-progress-card__next", exact_text: "Next: Joshua to Esther · due Dec 18"
      assert_no_selector ".goal-progress-card__people"
    end
    assert_no_text "1 to go"
    assert_step_line "Genesis to Deuteronomy", "Done Nov 14"
    assert_step_line "Joshua to Esther", "Due Dec 18"
    assert_selector ".goal-step__title--done", text: "Genesis to Deuteronomy"
    assert_no_selector "svg.octicon-pencil"
    assert_selector "button[aria-label='Edit step: Joshua to Esther'] svg.octicon-chevron-right"
    assert_equal page.evaluate_script("document.documentElement.clientWidth"), page.evaluate_script("document.documentElement.scrollWidth")
  end

  test "the add-step form is hidden until + Add step, adds a step, and Cancel hides it" do
    add_bible_reading_steps
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    assert_no_field "New step"
    add_step = find("#goal-steps button", exact_text: "Add step")
    assert_selector "#goal-steps button svg.octicon-plus"
    assert_touch_target add_step
    add_step.click

    assert_field "New step", focused: true
    assert_no_selector "#goal-steps button[data-action='add-row#open']"
    fill_in "New step", with: "Job to Song of Solomon"
    fill_in "Due (optional)", with: Date.new(2026, 12, 31)
    assert_button "Cancel"
    assert_accessible
    capture_screens("phone-goal-add-step", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
    on_a_phone

    click_on "Add step"
    assert_selector ".goal-step__title", exact_text: "Job to Song of Solomon"
    assert_step_line "Job to Song of Solomon", "Due Dec 31"
    assert_selector "#goal-progress-card h2", exact_text: "1 of 3 steps done"
    assert_no_field "New step"

    find("#goal-steps button", exact_text: "Add step").click
    fill_in "New step", with: "Isaiah to Malachi"
    click_on "Cancel"
    assert_no_field "New step"
    assert_selector "#goal-steps button:focus", exact_text: "Add step"
    find("#goal-steps button", exact_text: "Add step").click
    assert_field "New step", with: ""
  end

  test "a refused add keeps the form open with its error" do
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: @goal)

    find("#goal-steps button", exact_text: "Add step").click
    fill_in "New step", with: "   "
    click_on "Add step"

    assert_selector ".FormControl-inlineValidation", text: "can't be blank"
    assert_field "New step"
    assert_button "Cancel"
    assert_accessible
  end

  test "a family goal: the people line, and each row's second line for done, due, everyone and partly done" do
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: goals(:gospels))

    within("#goal-progress-card") do
      assert_selector "h2", exact_text: "3 of 7 steps done"
      assert_selector ".goal-progress-card__percent", exact_text: "42%"
      assert_selector ".goal-progress-card__next", exact_text: "Next: Read Luke together · due Feb 15"
      assert_equal [ "Hannah 2", "Sam 2", "Charlie 2", "Eli 4", "Sofia 2" ], all(".goal-progress-card__people li > span:last-child").map { it.text.squish }
      assert_selector ".goal-progress-card__people li .avatar", count: 5
    end
    assert_step_line "Read Matthew together", "Everyone · done Dec 12"
    assert_step_line "Draw a map of Jesus' travels", "Eli · done Jan 18"
    assert_step_line "Find three parables and explain one", "Eli and Sofia · Eli done, waiting on Sofia"
    assert_step_line "Read Luke together", "Everyone · due Feb 15"
    assert_no_selector "svg.octicon-pencil"
    assert_no_link "Schedule as a family study"
    assert_no_button "Eli Child done"

    # An adult ticks Everyone steps and their own part from the row; someone else's part is ticked from the panel.
    assert_selector step_row("Read Luke together", "input[type=checkbox]")
    assert_no_selector step_row("Draw a map of Jesus' travels", "input[type=checkbox]")
    assert_no_selector step_row("Find three parables and explain one", "input[type=checkbox]")
    assert_selector step_row("Share what each of us learned", "input[type=checkbox]")
    assert_equal page.evaluate_script("document.documentElement.clientWidth"), page.evaluate_script("document.documentElement.scrollWidth")
    assert_accessible
    capture_screens("phone-family-goal", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end

  test "ticking from a row updates the card" do
    sign_in identities(:spouse)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: goals(:gospels))

    find(step_row("Read Luke together", "input[type=checkbox]")).click

    assert_selector "#goal-progress-card h2", exact_text: "4 of 7 steps done"
    assert_selector "#goal-progress-card .goal-progress-card__percent", exact_text: "57%"
    assert_selector "#goal-progress-card .goal-progress-card__next", exact_text: "Next: Find three parables and explain one · due Feb 28"
    assert_step_line "Read Luke together", "Everyone · done Nov 14"
  end

  test "a child sees no box on an Everyone step, and a box only for their own part on a named step" do
    sign_in identities(:eli)
    visit_on_a_phone household_goal_url(household_id: households(:home), id: goals(:gospels))

    assert_no_selector step_row("Read Luke together", "input[type=checkbox]")
    assert_no_selector step_row("Share what each of us learned", "input[type=checkbox]")
    assert_selector step_row("Draw a map of Jesus' travels", "input[type=checkbox]:checked")
    assert_selector step_row("Find three parables and explain one", "input[type=checkbox]:checked")
    assert_no_button "Sofia Child"
    assert_no_selector "#goal-steps button[data-action='add-row#open']"
    assert_accessible

    find(step_row("Find three parables and explain one", "input[type=checkbox]")).click
    assert_step_line "Find three parables and explain one", "Eli and Sofia · due Feb 28"
    assert_selector "#goal-progress-card .goal-progress-card__people", text: "Eli 3"
  end

  test "a completed goal and an archived goal show no boxes and no + Add step" do
    goals(:gospels).complete(by: users(:spouse))
    add_bible_reading_steps
    @goal.archive(by: users(:spouse))
    sign_in identities(:spouse)

    [ goals(:gospels), @goal ].each do |goal|
      visit_on_a_phone household_goal_url(household_id: households(:home), id: goal)

      assert_selector "#goal-progress-card"
      assert_no_selector "#goal-steps input[type=checkbox]"
      assert_no_selector "#goal-steps button[data-action='add-row#open']"
      assert_no_field "New step"
    end
  end

  test "desktop keeps its progress box, the pencils and the add-step form, without + Add step" do
    sign_in identities(:spouse)
    visit household_goal_url(household_id: households(:home), id: goals(:gospels))

    assert_no_selector "#goal-progress-card"
    assert_selector "#goal-progress h2", exact_text: "3 of 7 steps done"
    assert_text "4 to go · next due Feb 15"
    assert_selector "#goal-progress .Label", text: "Eli Child · 4 of 6"
    assert_selector "#goal-steps svg.octicon-pencil", count: 7
    assert_no_selector "svg.octicon-chevron-right"
    assert_text "Everyone · Done together · Dec 12"
    assert_button "Eli Child done"
    assert_field "New step"
    assert_no_button "Cancel"
    assert_no_selector "#goal-steps button[data-action='add-row#open']"
    capture_screens("desktop-family-goal", viewports: ScreenshotHelper::VIEWPORTS.slice(:desktop))
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
      on_a_phone
      visit url
    end

    # Again after capture_screens, which leaves the desktop's viewport.
    def on_a_phone
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
    end

    # The menu's button is named only by its aria-label.
    def choose_from_goal_menu(item)
      assert_turbo_idle
      find("button[aria-label='Goal actions']").click
      find("[role=menuitem]", exact_text: item).click
    end

    # Frame phone-goal.png's two steps: the first done today, the second due Dec 18.
    def add_bible_reading_steps
      @goal.add_step(title: "Genesis to Deuteronomy").tick(for: nil, by: users(:spouse))
      @goal.add_step(title: "Joshua to Esther", due_on: Date.new(2026, 12, 18))
    end

    def step_row(title, selector)
      "##{ActionView::RecordIdentifier.dom_id(Goal::Step.all.find { it.title == title })} #{selector}"
    end

    def assert_step_line(title, line)
      assert_selector step_row(title, ".goal-step__phone-meta"), exact_text: line
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
