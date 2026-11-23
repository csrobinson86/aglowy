require "application_system_test_case"

# Settings → Go bags: the household's go-bag categories (docs/design/go-bags.md, Pages; frame
# docs/design/go-bags/go-bag-categories.png).
class SettingsGoBagCategoriesTest < ApplicationSystemTestCase
  test "an adult adds, renames and deletes a category from the section" do
    sign_in identities(:spouse)
    visit household_settings_go_bag_categories_url(household_id: households(:home))

    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Go bags"
    assert_text "Categories for The Head Family's go bags."
    assert_selector ".Box-row", text: /Water and food\s*1 item in 1 bag/
    capture_screens("settings-go-bag-categories")

    click_on "Add category"
    fill_in "Name", with: "For the car"
    click_on "Add category"
    assert_text "Category added."
    assert_selector ".Box-row", text: /For the car\s*No items/

    open_menu_of "For the car"
    find("[role=menuitem]", exact_text: "Rename").click
    assert_field "Name", with: "For the car", focused: true
    assert_accessible
    capture_screens("settings-go-bag-category-rename")
    fill_in "Name", with: "Car kit"
    click_on "Save"
    assert_text "Category renamed."
    assert_selector ".Box-row", text: /Car kit\s*No items/

    open_menu_of "Water and food"
    assert_selector "[role=menuitem]", exact_text: "Rename"
    assert_accessible
    find("[role=menuitem]", exact_text: "Delete…").click
    wait_for_dialog
    within("dialog[open]") do
      assert_selector "h1", text: "Delete Water and food?"
      assert_text "Its 1 item stays in its bag, under No category."
    end
    assert_accessible
    capture_screens("settings-go-bag-category-delete")
    within("dialog[open]") { click_on "Delete category" }

    assert_text "Category deleted."
    assert_no_selector ".Box-row", text: "Water and food"
    assert_nil go_bag_items(:water).reload.category
  end

  test "a refused name shows its error by the field, and Cancel puts the row back" do
    sign_in identities(:head)
    visit household_settings_go_bag_categories_url(household_id: households(:home))

    open_menu_of "Light, power and radio"
    find("[role=menuitem]", exact_text: "Rename").click
    fill_in "Name", with: ""
    click_on "Save"

    assert_text "Name can't be blank"
    assert_accessible
    click_on "Cancel"
    assert_selector ".Box-row", text: /Light, power and radio\s*1 item in 1 bag/
    assert_no_field "Name"
  end

  test "the section is in the nav for heads and adults and not for a child" do
    %i[ head spouse ].each do |identity|
      sign_in identities(identity)
      visit household_settings_profile_url(household_id: households(:home))
      within("nav[aria-label='Settings']") { click_on "Go bags" }
      assert_selector "h2", text: "Go bags"
    end

    sign_in identities(:eli)
    visit household_settings_profile_url(household_id: households(:home))
    assert_no_link "Go bags", href: household_settings_go_bag_categories_path(household_id: households(:home))
  end

  test "the Categories link on Go bags opens the section, for heads and adults" do
    sign_in identities(:spouse)
    visit household_go_bags_url(household_id: households(:home))

    click_on "Categories"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Go bags"

    sign_in identities(:eli)
    visit household_go_bags_url(household_id: households(:home))
    assert_selector "h1", text: "Go bags"
    assert_no_link "Categories"
  end

  test "on a phone, the Categories link, a category's menu and Add category are big enough to tap" do
    sign_in identities(:spouse)
    visit household_go_bags_url(household_id: households(:home))
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
    emulate_touch(true)

    assert_tappable find_link("Categories")
    click_on "Categories"
    assert_tappable find_link("Add category")
    open_menu_of "Water and food"
    assert_selector "[role=menuitem]", exact_text: "Rename"
    all("[role=menuitem]").each { assert_tappable it }
  ensure
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  private
    def assert_tappable(element)
      assert_operator element.evaluate_script("this.offsetHeight"), :>=, 44, "#{element.text} is too small to tap"
    end

    def open_menu_of(name)
      assert_turbo_idle
      find("button[aria-label='#{name} actions']").click
    end
end
