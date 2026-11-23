require "application_system_test_case"

# To buy across every bag, and the card on Go bags that leads there (docs/design/go-bags.md, To buy; frames
# go-bags.png and go-bags-to-buy.png; story #438).
class GoBagsToBuyTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 11, 23, 18)
    # Water we have, to use by soon; a flashlight to get; batteries we have, kept in the kitchen drawer. Charlie's bag
    # gets a thing to get, so there are two groups.
    go_bag_items(:water).update!(use_by: Date.new(2026, 12, 10))
    go_bags(:charlies).items.create!(name: "A small toy or book", quantity: "1")
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    emulate_touch(false)
  end

  test "the card's counts and link, then ticking a thing keeps it on the list, ticked, and unticking it works" do
    sign_in identities(:spouse)
    visit household_go_bags_url(household_id: households(:home))

    assert_selector "a.go-bags-to-buy-card", text: /3 things to buy\s*Across 2 bags · 1 needs replacing soon/
    assert_accessible
    capture_screens("go-bags-to-buy-card")

    find("a.go-bags-to-buy-card").click
    assert_selector "h1", text: "To buy"
    assert_selector "nav[aria-label='Main'] a[aria-current='page'] svg.octicon-briefcase"
    assert_equal [ "Family go bag · Kept in the hall closet", "Charlie's bag" ], all("main h2.go-bag__category").map(&:text)
    assert_accessible
    capture_screens("go-bags-to-buy")

    assert_turbo_idle
    check "We have Flashlight"
    assert_selector "#{box(:flashlight)}:checked:not([disabled]):focus"
    assert go_bag_items(:flashlight).reload.acquired?
    assert_selector ".Box-row", text: "Flashlight"
    capture_screens("go-bags-to-buy-ticked")

    uncheck "We have Flashlight"
    assert_selector "#{box(:flashlight)}:not(:checked):not([disabled]):focus"
    assert_not go_bag_items(:flashlight).reload.acquired?

    check "We have Flashlight"
    assert_selector "#{box(:flashlight)}:checked:not([disabled])"
    visit current_url
    assert_selector "h1", text: "To buy"
    assert_no_text "Flashlight"
  end

  test "a thing to replace opens its item, to set the new date" do
    sign_in identities(:head)
    visit to_buy_url

    within("##{ActionView::RecordIdentifier.dom_id(go_bag_items(:water), :to_buy)}") do
      assert_text "Use by Dec 10 · replace it"
      assert_no_field type: "checkbox"
      find("a[aria-label='Open Bottled water']").click
    end
    assert_selector "main h1", text: "Bottled water"
    assert_field "Use by", with: "2026-12-10"
    assert_accessible
  end

  test "with nothing to buy, the Blankslate" do
    GoBag::Item.find_each { it.acquire(by: users(:spouse)) }
    go_bag_items(:water).update!(use_by: nil)

    sign_in identities(:spouse)
    visit household_go_bags_url(household_id: households(:home))
    assert_selector "h1", text: "Go bags"
    assert_no_selector "a.go-bags-to-buy-card"

    visit to_buy_url
    assert_selector ".blankslate h2", text: "Nothing to buy."
    assert_text "Every bag is ready."
    assert_accessible
    capture_screens("go-bags-to-buy-empty")
  end

  private
    def to_buy_url
      household_go_bags_shopping_list_url(household_id: households(:home))
    end

    def box(name)
      "input[name=to_buy_go_bag_item_#{go_bag_items(name).id}_have]"
    end
end
