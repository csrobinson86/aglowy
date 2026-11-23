require "test_helper"

# Ticking "we have it" from an item's row (docs/design/go-bags.md, Item rows; story #437): it saves straight away, and a
# Turbo Stream redraws the row, the ready box and the tabs' counters.
class GoBags::Items::AcquisitionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 23, 18)
    @bag = go_bags(:family)
  end

  test "ticking replaces the row, the ready box and the counters" do
    sign_in identities(:spouse)
    post acquisition_path(go_bag_items(:flashlight)), as: :turbo_stream

    assert_response :success
    assert go_bag_items(:flashlight).reload.acquired?
    assert_equal users(:spouse), go_bag_items(:flashlight).acquisition.acquired_by
    assert_select "turbo-stream[action=update][target=#{dom_id(go_bag_items(:flashlight))}] template" do
      assert_select "input[type=checkbox][checked][autofocus]"
      assert_select "form[action=?] input[name=_method][value=delete]", acquisition_path(go_bag_items(:flashlight))
    end
    assert_select "turbo-stream[action=replace][target=go-bag-progress]", text: /3 of 3 ready\s*100%/
    assert_equal [ "All 3", "To buy 0", "Use by soon 0" ], css_select("turbo-stream[action=replace][target=go-bag-tabs] template nav a").map { it.text.squish }
  end

  test "unticking replaces them too, keeping the tab it was ticked on" do
    sign_in identities(:head)
    delete acquisition_path(go_bag_items(:water), show: "to_buy"), as: :turbo_stream

    assert_response :success
    assert_not go_bag_items(:water).reload.acquired?
    assert_select "turbo-stream[target=#{dom_id(go_bag_items(:water))}] template" do
      assert_select "input[type=checkbox]:not([checked])"
      assert_select ".go-bag-item-row__line", text: /To buy/
    end
    assert_select "turbo-stream[action=replace][target=go-bag-progress]", text: /1 of 3 ready/
    assert_select "turbo-stream[action=replace][target=go-bag-tabs] template" do
      assert_select "a[aria-current=page]", text: /To buy\s*2/
    end
  end

  test "twice is safe" do
    sign_in identities(:spouse)
    assert_difference -> { GoBag::Item::Acquisition.count } do
      2.times { post acquisition_path(go_bag_items(:flashlight)), as: :turbo_stream }
    end
    assert_response :success

    assert_difference -> { GoBag::Item::Acquisition.count }, -1 do
      2.times { delete acquisition_path(go_bag_items(:flashlight)), as: :turbo_stream }
    end
    assert_response :success
  end

  test "a child is refused, even with a crafted request" do
    sign_in Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)

    post acquisition_path(go_bag_items(:flashlight)), as: :turbo_stream
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_not go_bag_items(:flashlight).reload.acquired?

    delete acquisition_path(go_bag_items(:water)), as: :turbo_stream
    assert_redirected_to household_root_path(household_id: households(:home))
    assert go_bag_items(:water).reload.acquired?
  end

  test "an item from another bag through this bag's URL is a 404" do
    sign_in identities(:spouse)
    post household_go_bag_item_acquisition_path(household_id: households(:home), go_bag_id: go_bags(:charlies), item_id: go_bag_items(:flashlight)), as: :turbo_stream

    assert_response :not_found
    assert_not go_bag_items(:flashlight).reload.acquired?
  end

  private
    def acquisition_path(item, **params)
      household_go_bag_item_acquisition_path(household_id: households(:home), go_bag_id: @bag, item_id: item, **params)
    end

    def dom_id(...)
      ActionView::RecordIdentifier.dom_id(...)
    end
end
