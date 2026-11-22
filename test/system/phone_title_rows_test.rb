require "application_system_test_case"

# The top-level pages' title rows on a phone (docs/design/phone.md, The rules: 1 and 3; story #409): the primary button
# sits at the right of the h1, as wide as its label and 44px tall, and a description that only explains the page is
# hidden. Desktop doesn't change.
class PhoneTitleRowsTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    visit root_url
    on_a_phone
  end

  teardown do
    on_desktop
  end

  test "Home's New sits beside the title, keeps the household and date under it, and opens its menu under the button" do
    visit household_root_url(household_id: households(:home))
    assert_turbo_idle

    button = find("#home-new-menu-button")
    assert_title_row button
    assert_selector ".Subhead-description", text: "#{households(:home).name} · "
    assert_menu_opens_under button, "home-new-menu"
    assert_accessible
    find("body").send_keys(:escape)
    capture_screens("phone-title-row-home")
  end

  test "Calendar's New sits beside the title, and the description is hidden on a phone" do
    visit household_calendar_url(household_id: households(:home))
    assert_turbo_idle

    button = find("#calendar-new-menu-button")
    assert_title_row button
    assert_no_selector ".Subhead-description", text: "meetings, studies and events"
    assert_menu_opens_under button, "calendar-new-menu"
    assert_accessible
    find("body").send_keys(:escape)
    capture_screens("phone-title-row-calendar")

    on_desktop
    visit household_calendar_url(household_id: households(:home))
    assert_selector ".Subhead-description", text: "#{households(:home).name}'s meetings, studies and events, with your own times."
  end

  test "Family studies' button reads New on a phone and Schedule a study on desktop" do
    visit household_family_studies_url(household_id: households(:home))

    button = find("main .Subhead-actions a", text: "New")
    assert_equal "New", button.text
    assert_title_row button
    assert_accessible
    capture_screens("phone-title-row-family-studies")

    on_desktop
    visit household_family_studies_url(household_id: households(:home))
    button = find("main .Subhead-actions a", text: "Schedule a study")
    assert_equal "Schedule a study", button.text
    button.click
    assert_current_path new_household_family_study_path(household_id: households(:home))
  end

  test "Family goals' New goal sits beside the title, and the description shows only on desktop" do
    visit household_goals_url(household_id: households(:home))

    assert_title_row find("main .Subhead-actions a", exact_text: "New goal")
    assert_no_text "Goals the whole household works toward together."
    assert_accessible
    capture_screens("phone-title-row-family-goals")

    on_desktop
    visit household_goals_url(household_id: households(:home))
    assert_text "Goals the whole household works toward together."
  end

  test "My goals' New goal sits beside the title" do
    visit household_my_goals_url(household_id: households(:home))

    assert_title_row find("main .Subhead-actions a", exact_text: "New goal")
    assert_accessible
    capture_screens("phone-title-row-my-goals")
  end

  private
    def on_a_phone
      emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
      emulate_touch(true)
    end

    def on_desktop
      cdp("Emulation.clearDeviceMetricsOverride")
      cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    end

    # The button's top is level with the h1's, its right edge at the page's padding, nothing scrolls sideways, and
    # it's a touch target.
    def assert_title_row(button)
      assert_in_delta rect(find("main h1"), "top"), rect(button, "top"), 4, "the button isn't beside the title"
      padding = find("main").evaluate_script("parseFloat(getComputedStyle(this).paddingRight)")
      assert_operator padding, :>, 0
      assert_operator page_width - rect(button, "right"), :<=, padding + 1, "the button isn't at the right of the page"
      assert_equal page_width, evaluate_script("document.documentElement.scrollWidth")
      assert_touch_target button
    end

    # The menu opens below its button, lined up with the button's end.
    def assert_menu_opens_under(button, menu_id)
      button.click
      list = find("##{menu_id}-list")
      wait_for_animations
      assert_operator rect(list, "top"), :>=, rect(button, "bottom")
      assert_in_delta rect(button, "right"), rect(list, "right"), 1, "the menu isn't aligned to the button's end"
      all("##{menu_id}-list [role=menuitem]").each { assert_touch_target it }
    end

    def page_width
      evaluate_script("document.documentElement.clientWidth")
    end

    def rect(element, side)
      element.evaluate_script("this.getBoundingClientRect().#{side}")
    end
end
