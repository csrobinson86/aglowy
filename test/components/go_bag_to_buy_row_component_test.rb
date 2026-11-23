require "test_helper"

class GoBagToBuyRowComponentTest < ViewComponent::TestCase
  setup { travel_to Time.utc(2026, 11, 23, 18) }

  test "a thing to get: the box that ticks it, and how many" do
    go_bag_items(:flashlight).update!(quantity: "2")
    render_item(:flashlight)

    assert_selector "form[action='#{path_to(:flashlight)}/acquisition?from=to_buy'][method=post] input[type=checkbox][name=to_buy_go_bag_item_#{go_bag_items(:flashlight).id}_have]:not([checked])"
    assert_unchecked_field "We have Flashlight"
    assert_selector ".go-bag-item-row__line", exact_text: "2"
    assert_no_selector "a"
  end

  test "a thing to get with no quantity has no line" do
    render_item(:flashlight)

    assert_no_selector ".go-bag-item-row__line"
  end

  test "a thing to replace: a clock, when to use it by in the attention color, and › opening its page" do
    go_bag_items(:water).update!(use_by: Date.new(2026, 12, 20))
    render_item(:water)

    assert_selector "svg.octicon-clock.color-fg-attention"
    assert_selector ".go-bag-item-row__line.color-fg-attention", exact_text: "Use by Dec 20 · replace it"
    assert_selector "a[href='#{path_to(:water)}/edit'][aria-label='Open Bottled water']:not([data-turbo-frame])"
    assert_no_selector "input"
  end

  test "an expired thing to replace is in the danger color" do
    go_bag_items(:water).update!(use_by: Date.new(2026, 11, 20))
    render_item(:water)

    assert_selector "svg.octicon-clock.color-fg-danger"
    assert_selector ".go-bag-item-row__line.color-fg-danger", exact_text: "Expired Nov 20 · replace it"
  end

  test "just ticked, it keeps its box, ticked, which unticks it, and takes focus" do
    go_bag_items(:water).update!(use_by: Date.new(2026, 12, 20))
    render_item(:water, box: true, focus: true)

    assert_selector "form[action='#{path_to(:water)}/acquisition?from=to_buy'] input[name=_method][value=delete]", visible: :all
    assert_selector "input[type=checkbox][checked][autofocus]"
    assert_selector ".go-bag-item-row__line", exact_text: "6 gallons"
    assert_no_selector "svg.octicon-clock, a"
  end

  private
    def path_to(name)
      item = go_bag_items(name)
      "/#{households(:home).id}/go_bags/#{item.go_bag_id}/items/#{item.id}"
    end

    def render_item(name, **options)
      render_inline(GoBagToBuyRowComponent.new(item: GoBag::Item.includes(:acquisition).find(go_bag_items(name).id), today: households(:home).today, **options))
    end
end
