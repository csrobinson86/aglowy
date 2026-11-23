require "application_system_test_case"

class GoBagsTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 23, 18) }

  test "a head makes a bag with suggested items and sees it grouped by category, then edits and deletes it" do
    households(:home).go_bags.destroy_all
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    within("nav[aria-label='Main']") { click_on "Go bags" }
    assert_selector "h1", text: "Go bags"
    assert_selector "nav[aria-label='Main'] a[aria-current='page'] svg.octicon-briefcase"
    assert_selector ".blankslate h2", text: "No go bags yet"
    assert_accessible
    capture_screens("go-bags-empty")

    within(".blankslate") { click_on "New go bag" }
    assert_selector "h1", text: "New go bag"
    assert_checked_field "Start with suggested items"
    assert_text "So anyone can grab it in a hurry"
    assert_accessible
    capture_screens("go-bag-new")

    fill_in "Name", with: "Family go bag"
    fill_in "Where it's kept", with: "the hall closet"
    click_on "Create bag"

    assert_selector "h1", text: "Family go bag"
    assert_selector "#go-bag-meta", text: "Kept in the hall closet · For everyone"
    assert_selector "#go-bag-progress", text: "0 of 37 ready"
    assert_equal GoBag::Suggestions.new.categories.map(&:name), all("main h2.go-bag__category").map(&:text)
    within(:xpath, "//h2[normalize-space()='Water and food']/following-sibling::*[1]") do
      assert_selector ".Box-row", text: /Bottled water\s*Still to get · 1 gallon a person a day, for 3 days/
    end
    assert_accessible
    capture_screens("go-bag")

    within(".Subhead") { click_on "Edit" }
    assert_selector "h1", text: "Edit go bag"
    assert_no_field "Start with suggested items"
    assert_accessible
    fill_in "Name", with: "Home go bag"
    select "Charlie Child", from: "For"
    click_on "Save"
    assert_selector "h1", text: "Home go bag"
    assert_selector "#go-bag-meta", text: "Kept in the hall closet · For Charlie"

    assert_turbo_idle
    find("button[aria-label='Go bag actions']").click
    find("[role=menuitem]", exact_text: "Delete bag…").click
    wait_for_dialog
    within("dialog[open]") do
      assert_selector "h1", text: "Delete Home go bag?"
      assert_text "Its 37 items are deleted too."
    end
    assert_accessible
    capture_screens("go-bag-delete")
    within("dialog[open]") { click_on "Delete bag" }

    assert_text "Go bag deleted."
    assert_selector ".blankslate h2", text: "No go bags yet"
  end

  test "the list shows each bag, how many to buy and the guide" do
    sign_in identities(:spouse)
    visit household_go_bags_url(household_id: households(:home))

    assert_link "New"
    assert_selector ".Box-row", text: /Family go bag\s*Kept in the hall closet · 1 to buy/
    assert_selector ".Box-row", text: /Charlie's bag\s*No items yet/
    assert_link "When Disaster Strikes—Steps That Can Save Lives", href: "https://wol.jw.org/en/wol/d/r1/lp-e/102017165"
    assert_accessible
    capture_screens("go-bags")
  end

  test "a child sees the list and a bag, with no New, menu or edit links" do
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    visit household_go_bags_url(household_id: households(:home))

    assert_selector ".Box-row", text: /Family go bag\s*Kept in the hall closet · 2 of 3 ready/
    assert_no_link "New"
    assert_accessible
    capture_screens("go-bags-child")

    click_on "Family go bag"
    assert_selector "h1", text: "Family go bag"
    assert_selector "#go-bag-meta", text: "Kept in the hall closet · The adults keep it up to date"
    assert_selector ".Box-row", text: /Flashlight\s*Still to get/
    assert_selector "svg[aria-label='We have it']", count: 2
    assert_no_link "Edit"
    assert_no_selector "button[aria-label='Go bag actions']", visible: :all
    assert_accessible
    capture_screens("go-bag-child")
  end
end
