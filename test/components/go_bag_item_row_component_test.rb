require "test_helper"

class GoBagItemRowComponentTest < ViewComponent::TestCase
  setup { travel_to Time.utc(2026, 11, 23, 18) }

  test "to get" do
    render_item(:flashlight)

    assert_selector ".go-bag-item-row__name", text: "Flashlight"
    assert_selector ".go-bag-item-row__line", exact_text: "To buy"
    assert_no_selector "a"
  end

  test "ready in the bag, with how many" do
    render_item(:water)

    assert_selector ".go-bag-item-row__line", exact_text: "6 gallons · in the bag"
  end

  test "ready and kept somewhere else, with no quantity" do
    render_item(:batteries)

    assert_selector ".go-bag-item-row__line", exact_text: "Kept in the kitchen drawer"
  end

  test "use by soon is in the attention color" do
    go_bag_items(:water).update!(use_by: Date.new(2026, 12, 20))
    render_item(:water)

    assert_selector ".go-bag-item-row__line", exact_text: "6 gallons · in the bag · use by Dec 20"
    assert_selector ".color-fg-attention", exact_text: "use by Dec 20"
  end

  test "a use-by date that isn't soon has no color, and shows the year when it isn't this one" do
    go_bag_items(:water).update!(use_by: Date.new(2027, 8, 1))
    render_item(:water)

    assert_selector ".go-bag-item-row__line", exact_text: "6 gallons · in the bag · use by Aug 1, 2027"
    assert_no_selector ".color-fg-attention, .color-fg-danger"
  end

  test "expired reads expired, in the danger color" do
    go_bag_items(:water).update!(use_by: Date.new(2026, 11, 20))
    render_item(:water)

    assert_selector ".color-fg-danger", exact_text: "expired Nov 20"
    assert_no_selector ".color-fg-attention"
  end

  test "a long name is cut to two lines" do
    go_bag_items(:flashlight).update!(name: "A wind-up flashlight with a radio, a siren and a phone charger built into the handle")
    render_item(:flashlight)

    assert_selector ".go-bag-item-row__name", text: /\AA wind-up flashlight/
  end

  test "a child's row: an icon with its label, Still to get, and no colors" do
    go_bag_items(:water).update!(use_by: Date.new(2026, 11, 20))

    render_item(:flashlight, read_only: true)
    assert_selector "svg.octicon-issue-draft[role=img][aria-label='Still to get']"
    assert_selector ".go-bag-item-row__line", exact_text: "Still to get"

    render_item(:water, read_only: true)
    assert_selector "svg.octicon-check-circle.color-fg-success[role=img][aria-label='We have it']"
    assert_selector ".go-bag-item-row__line", exact_text: "6 gallons · in the bag · expired Nov 20"
    assert_no_selector ".color-fg-attention, .color-fg-danger"
  end

  private
    def render_item(name, read_only: false)
      render_inline(GoBagItemRowComponent.new(item: GoBag::Item.includes(:acquisition).find(go_bag_items(name).id), today: households(:home).today, read_only:))
    end
end
