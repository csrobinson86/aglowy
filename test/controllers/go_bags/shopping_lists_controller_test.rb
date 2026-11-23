require "test_helper"

# To buy across every bag, and the To buy card on Go bags (docs/design/go-bags.md, To buy and Go bags; story #438).
# Water we have, to use by soon; a flashlight to get; batteries we have, kept in the kitchen drawer.
class GoBags::ShoppingListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 23, 18)
    go_bag_items(:water).update!(use_by: Date.new(2026, 12, 10))
  end

  test "a head and an adult see a group per bag with something to buy: a box for a thing to get, a clock and › for a thing to replace" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get to_buy_path

      assert_response :success
      assert_select "title", "To buy · The Head Family · Aglowy"
      assert_select "h1", "To buy"
      assert_select "main", text: /Tick a thing once you've bought it\./
      assert_select "main a[href='#{household_go_bags_path(household_id: households(:home))}']", text: "Go bags"
      assert_equal [ "Family go bag · Kept in the hall closet" ], css_select("main h2.go-bag__category").map { it.text.squish }
      assert_equal [ "Flashlight", "Bottled water" ], css_select("main .go-bag-item-row__name").map { it.text.strip }
      assert_select "##{dom_id(go_bag_items(:flashlight), :to_buy)}" do
        assert_select "form[action=?][method=post] input[type=checkbox]:not([checked])", acquisition_path(go_bag_items(:flashlight))
      end
      assert_select "##{dom_id(go_bag_items(:water), :to_buy)}", text: /Bottled water\s*Use by Dec 10 · replace it/ do
        assert_select "input", count: 0
        assert_select "svg.octicon-clock"
        assert_select "a[href=?][aria-label='Open Bottled water']", edit_household_go_bag_item_path(household_id: households(:home), go_bag_id: go_bags(:family), id: go_bag_items(:water))
      end
      assert_select "main", { text: /Spare batteries/, count: 0 }
    end
  end

  test "a child is refused" do
    sign_in child_identity
    get to_buy_path

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "only this household's bags" do
    households(:other).go_bags.create!(name: "Theirs", created_by: users(:outsider)).items.create!(name: "Their torch")

    sign_in identities(:spouse)
    get to_buy_path
    assert_select "main", { text: /Theirs|Their torch/, count: 0 }

    get household_go_bags_shopping_list_path(household_id: households(:other))
    assert_response :not_found
  end

  test "the count matches each bag's N to buy and the card" do
    go_bags(:charlies).items.create!(name: "A small toy or book")
    go_bags(:charlies).items.create!(name: "A favorite snack")

    sign_in identities(:spouse)
    get household_go_bags_path(household_id: households(:home))
    assert_select "main .Box-row", text: /Family go bag\s*Kept in the hall closet · 2 to buy/
    assert_select "main .Box-row", text: /Charlie's bag\s*2 to buy/
    assert_select "main a.go-bags-to-buy-card[href='#{to_buy_path}']", text: /4 things to buy\s*Across 2 bags · 1 needs replacing soon/ do
      assert_select "svg.octicon-checklist.color-fg-attention"
    end

    get to_buy_path
    assert_equal [ "Family go bag · Kept in the hall closet", "Charlie's bag" ], css_select("main h2.go-bag__category").map { it.text.squish }
    assert_equal [ 2, 2 ], css_select("main section").map { css_select(it, ".Box-row").size }
  end

  test "the card leaves out replacing when nothing needs it, and is hidden when there's nothing to buy and from children" do
    go_bag_items(:water).update!(use_by: nil)

    sign_in identities(:head)
    get household_go_bags_path(household_id: households(:home))
    assert_select "a.go-bags-to-buy-card", text: /\A\s*1 thing to buy\s*Across 1 bag\s*\z/

    sign_in child_identity
    get household_go_bags_path(household_id: households(:home))
    assert_select "a.go-bags-to-buy-card", count: 0

    go_bag_items(:flashlight).acquire(by: users(:spouse))
    sign_in identities(:head)
    get household_go_bags_path(household_id: households(:home))
    assert_select "a.go-bags-to-buy-card", count: 0
  end

  test "with nothing to buy, the Blankslate" do
    go_bag_items(:flashlight).acquire(by: users(:spouse))
    go_bag_items(:water).update!(use_by: Date.new(2027, 3, 1))

    sign_in identities(:spouse)
    get to_buy_path
    assert_select ".blankslate h2", "Nothing to buy."
    assert_select ".blankslate", text: /Every bag is ready\./
    assert_select "main .Box-row", count: 0
  end

  test "it asks no more queries for three bags of many items than for one small bag" do
    sign_in identities(:spouse)
    get to_buy_path
    one = queries_for { get to_buy_path }

    2.times { |n| households(:home).go_bags.create!(name: "Bag #{n}", created_by: users(:spouse)) }
    households(:home).go_bags.each { |bag| 5.times { bag.items.create!(name: "Thing #{it}", category: go_bag_categories(:water_food)) } }
    assert_equal one, queries_for { get to_buy_path }
  end

  private
    def to_buy_path
      household_go_bags_shopping_list_path(household_id: households(:home))
    end

    def acquisition_path(item)
      household_go_bag_item_acquisition_path(household_id: households(:home), go_bag_id: item.go_bag_id, item_id: item, from: "to_buy")
    end

    def dom_id(...)
      ActionView::RecordIdentifier.dom_id(...)
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end

    def queries_for(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
