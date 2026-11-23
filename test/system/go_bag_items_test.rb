require "application_system_test_case"

# Keeping a bag up to date from its page (docs/design/go-bags.md, A bag, Item rows and An item; frames go-bag.png,
# go-bag-dark.png and go-bag-item.png; story #437): tick what we have, add and change items in a dialog, and filter to
# what's still to buy or needs using soon.
class GoBagItemsTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 23, 18)
    # Water we have, to use by soon; a flashlight to get; batteries we have, kept in the kitchen drawer.
    go_bag_items(:water).update!(use_by: Date.new(2026, 12, 10))
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    emulate_touch(false)
  end

  test "a head adds an item from a section, edits it in the dialog, ticks it, filters to To buy and Use by soon, and removes it" do
    sign_in identities(:head)
    visit bag_url

    assert_selector "#go-bag-progress", text: "2 of 3 ready"
    assert_tabs "All 3", "To buy 2", "Use by soon 1", selected: "All"
    capture_screens("go-bag-items")

    within(section("Light, power and radio")) { click_on "Add item" }
    wait_for_dialog
    within("dialog[open]") do
      assert_selector "h1", text: "Add item"
      assert_select "Category", selected: "Light, power and radio"
      assert_unchecked_field "We have it"
    end
    assert_accessible
    capture_screens("go-bag-item-new")

    within("dialog[open]") do
      fill_in "Name", with: "Whistle"
      fill_in "How many", with: "1"
      click_on "Add item"
    end
    assert_no_selector "dialog[open]"
    within(section("Light, power and radio")) { assert_selector ".Box-row", text: /Whistle\s*To buy · 1/ }
    assert_selector "#go-bag-progress", text: "2 of 4 ready"
    assert_tabs "All 4", "To buy 3", "Use by soon 1", selected: "All"

    open_item "Whistle"
    within("dialog[open]") do
      assert_selector "h1", text: "Whistle"
      assert_field "Name", with: "Whistle"
      fill_in "Name", with: "Loud whistle"
      fill_in "Stored somewhere else?", with: "the car"
      click_on "Save"
    end
    assert_no_selector "dialog[open]"
    within(section("Light, power and radio")) { assert_selector ".Box-row", text: /Loud whistle\s*To buy · 1 · Kept in the car/ }

    assert_turbo_idle
    check "We have Loud whistle"
    assert_selector "#go-bag-progress", text: "3 of 4 ready"
    assert_tabs "All 4", "To buy 2", "Use by soon 1", selected: "All"
    assert_checked_field "We have Loud whistle"
    assert go_bags(:family).items.find { it.name == "Loud whistle" }.acquired?

    within("nav[aria-label='Show']") { click_on "To buy" }
    assert_tabs "All 4", "To buy 2", "Use by soon 1", selected: "To buy"
    assert_equal [ "Bottled water", "Flashlight" ], all(".go-bag-item-row__name").map(&:text)
    assert_accessible
    capture_screens("go-bag-to-buy-tab")

    within("nav[aria-label='Show']") { click_on "Use by soon" }
    assert_tabs "All 4", "To buy 2", "Use by soon 1", selected: "Use by soon"
    assert_equal [ "Bottled water" ], all(".go-bag-item-row__name").map(&:text)
    capture_screens("go-bag-use-by-soon-tab")

    within("nav[aria-label='Show']") { click_on "All" }
    open_item "Loud whistle"
    within("dialog[open]") { click_on "Remove item" }
    assert_no_selector "dialog[open]"
    assert_no_text "Loud whistle"
    assert_selector "#go-bag-progress", text: "2 of 3 ready"
  end

  test "a box is held until its row redraws, so a quick untick can't send the tick again" do
    sign_in identities(:spouse)
    visit bag_url
    assert_turbo_idle

    # Both clicks in one script, so the redraw can't come between them.
    held = find_field("We have Flashlight").evaluate_script("(() => { this.click(); const held = this.disabled; this.click(); return held })()")
    assert held, "the box wasn't held after the tick"

    assert_selector "#go-bag-progress", text: "3 of 3 ready"
    assert_selector "input[name=go_bag_item_#{go_bag_items(:flashlight).id}_have]:checked:not([disabled]):focus"
    assert go_bag_items(:flashlight).reload.acquired?
  end

  test "saving or removing in the dialog puts focus back on the link that opened it, or its section's Add item" do
    sign_in identities(:spouse)
    visit bag_url

    assert_turbo_idle
    within(section("Light, power and radio")) { click_on "Add item" }
    wait_for_dialog
    within("dialog[open]") do
      fill_in "Name", with: "Whistle"
      click_on "Add item"
    end
    assert_no_selector "dialog[open]"
    assert_selector "a[aria-label='Add item to Light, power and radio']:focus"

    open_item "Flashlight"
    within("dialog[open]") do
      fill_in "Name", with: "Torch"
      click_on "Save"
    end
    assert_no_selector "dialog[open]"
    assert_selector "a[aria-label='Open Torch']:focus"

    open_item "Torch"
    within("dialog[open]") { click_on "Remove item" }
    assert_no_text "Torch"
    assert_selector "a[aria-label='Add item to Light, power and radio']:focus"
  end

  test "an empty tab shows its line" do
    go_bag_items(:water).update!(use_by: nil)
    sign_in identities(:spouse)
    visit bag_url(show: "use_by_soon")

    assert_selector ".blankslate", text: "Nothing to use soon."
    assert_tabs "All 3", "To buy 1", "Use by soon 0", selected: "Use by soon"
    assert_accessible
    capture_screens("go-bag-use-by-soon-empty")
  end

  test "on a phone the dialog opens from the bottom, and the checkbox and › are 44px to touch" do
    sign_in identities(:spouse)
    on_a_phone
    visit bag_url

    assert_touch_target find_field("We have Flashlight")
    assert_touch_target find("a[aria-label='Open Flashlight']")
    open_item "Bottled water"

    dialog = find("dialog[open]")
    assert_in_delta page.evaluate_script("window.innerHeight"), dialog.evaluate_script("this.getBoundingClientRect().bottom"), 1, "the dialog isn't at the bottom"
    within(dialog) do
      assert_selector "h1", text: "Bottled water"
      assert_checked_field "We have it"
      assert_field "Use by (optional)", with: "2026-12-10"
    end
    assert_accessible
    capture_screens("go-bag-item")
  end

  test "opening an item's edit URL directly shows the page with a back row" do
    sign_in identities(:spouse)
    on_a_phone
    visit edit_household_go_bag_item_url(household_id: households(:home), go_bag_id: go_bags(:family), id: go_bag_items(:flashlight))

    assert_no_selector "dialog#go-bag-item-dialog", visible: :all
    assert_selector ".back-row a", exact_text: "Family go bag"
    assert_selector "h1", text: "Flashlight"
    assert_accessible
    capture_screens("go-bag-item-page")

    check "We have it"
    click_on "Save"
    assert_selector "main h1", text: "Family go bag"
    assert_checked_field "We have Flashlight"
  end

  private
    def bag_url(**params)
      household_go_bag_url(household_id: households(:home), id: go_bags(:family), **params)
    end

    def section(heading)
      find(:xpath, "//section[h2[normalize-space()='#{heading}']]")
    end

    def open_item(name)
      assert_turbo_idle
      find("a[aria-label='Open #{name}']").click
      wait_for_dialog
    end

    # Each tab's label and counter, in order, and the one selected. Matched as a whole, so Capybara waits for a redraw.
    def assert_tabs(*tabs, selected:)
      assert_selector "nav[aria-label='Show'] a[aria-current=page]", text: selected
      pattern = tabs.map { |tab| tab.split.map { Regexp.escape(it) }.join('\s*') }.join('\s*')
      assert_selector "nav[aria-label='Show']", text: /\A#{pattern}\z/
    end

    def on_a_phone
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
    end
end
