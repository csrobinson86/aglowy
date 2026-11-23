require "test_helper"

class GoBagRowComponentTest < ViewComponent::TestCase
  setup { travel_to Time.utc(2026, 11, 23, 18) }

  test "a bag with things to buy: the whole row opens it, with where it's kept and how many to buy" do
    render_inline(GoBagRowComponent.new(go_bag: preloaded(:family), today:))

    assert_selector "a[href='/#{households(:home).id}/go_bags/#{go_bags(:family).id}']", text: /Family go bag\s*Kept in the hall closet · 1 to buy/
    assert_selector "a svg.octicon-briefcase[aria-hidden=true]"
    assert_selector "a svg.octicon-chevron-right[aria-hidden=true]"
  end

  test "a bag with everything ready, and an item to use soon counted as to buy" do
    go_bag_items(:flashlight).acquire(by: users(:spouse))
    render_inline(GoBagRowComponent.new(go_bag: preloaded(:family), today:))
    assert_text "Kept in the hall closet · All ready"

    go_bag_items(:water).update!(use_by: today + 10.days)
    render_inline(GoBagRowComponent.new(go_bag: preloaded(:family), today:))
    assert_text "Kept in the hall closet · 1 to buy"
  end

  test "a bag kept nowhere in particular, with no items yet" do
    render_inline(GoBagRowComponent.new(go_bag: preloaded(:charlies), today:))

    assert_selector ".go-bag-row__line", exact_text: "No items yet"
  end

  test "a child's row says how ready the bag is instead of what's to buy" do
    render_inline(GoBagRowComponent.new(go_bag: preloaded(:family), today:, read_only: true))

    assert_text "Kept in the hall closet · 2 of 3 ready"
    assert_no_text "to buy"
  end

  test "a long name is cut to two lines" do
    go_bags(:family).update!(name: "The big family go bag that sits by the front door, beside the shoes and coats")
    render_inline(GoBagRowComponent.new(go_bag: preloaded(:family), today:))

    assert_selector ".go-bag-row__name", text: "The big family go bag that sits by the front door, beside the shoes and coats"
  end

  private
    def preloaded(name)
      GoBag.preloaded.find(go_bags(name).id)
    end

    def today
      households(:home).today
    end
end
