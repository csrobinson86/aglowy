require "test_helper"

# An item in a go bag, and the words for where it stands (docs/design/go-bags.md, Words; GoBag::Item).
class GoBag::ItemTest < ActiveSupport::TestCase
  setup do
    @bag = go_bags(:family)
  end

  test "to_get and acquired split the bag's items by whether we have them" do
    assert_equal [ go_bag_items(:flashlight) ], @bag.items.to_get.to_a
    assert_equal [ go_bag_items(:water), go_bag_items(:batteries) ].sort_by(&:id), @bag.items.acquired.sort_by(&:id)
  end

  # In Auckland it's already the 24th while the server's date is the 23rd, so a day counted from the server's date
  # would be off by one.
  test "use by soon and to buy count 30 days from the household's today, either side of 30 days and for a past date" do
    households(:home).update!(time_zone: "Auckland")

    travel_to Time.utc(2026, 11, 23, 12) do
      today = households(:home).today
      assert_equal Date.new(2026, 11, 24), today

      day_30 = acquired_item("Day 30", use_by: today + 30)
      day_31 = acquired_item("Day 31", use_by: today + 31)
      passed = acquired_item("Passed", use_by: today - 1)
      undated = acquired_item("Undated", use_by: nil)
      to_get = @bag.items.create!(name: "To get, day 31", use_by: today + 31)

      assert_equal [ day_30, passed ].sort_by(&:id), @bag.items.use_by_soon(today).sort_by(&:id)
      assert_equal [ go_bag_items(:flashlight), day_30, passed, to_get ].sort_by(&:id), @bag.items.to_buy(today).sort_by(&:id)

      assert day_30.use_by_soon?(today) && day_30.to_buy?(today)
      assert_not day_31.use_by_soon?(today) || day_31.to_buy?(today)
      assert passed.use_by_soon?(today) && passed.to_buy?(today) && passed.expired?(today)
      assert_not undated.use_by_soon?(today) || undated.to_buy?(today) || undated.expired?(today)
      assert_not day_30.expired?(today)
      assert to_get.to_buy?(today)
      assert_not to_get.use_by_soon?(today)
    end
  end

  test "acquire twice leaves one record and keeps who ticked first" do
    item = go_bag_items(:flashlight)

    assert_difference -> { GoBag::Item::Acquisition.count }, 1 do
      item.acquire(by: users(:spouse))
      item.acquire(by: users(:head))
    end

    assert item.acquired?
    assert_equal users(:spouse), item.acquisition.acquired_by
  end

  test "unacquire deletes the record and is safe to repeat" do
    item = go_bag_items(:water)

    item.unacquire
    item.unacquire

    assert_not item.acquired?
    assert_not GoBag::Item::Acquisition.exists?(item:)
  end

  test "save_with have: true saves the item and ticks it" do
    item = go_bag_items(:flashlight)
    item.quantity = "2"

    assert item.save_with(have: true, by: users(:spouse))

    assert_equal "2", item.reload.quantity
    assert item.acquired?
  end

  test "save_with have: false saves the item and unticks it" do
    item = go_bag_items(:water)
    item.stored_at = "the garage"

    assert item.save_with(have: "0", by: users(:spouse))

    assert_equal "the garage", item.reload.stored_at
    assert_not item.acquired?
  end

  test "save_with have: nil saves the item and leaves the tick as it was" do
    item = go_bag_items(:water)
    item.quantity = "8 gallons"

    assert item.save_with(have: nil, by: users(:spouse))

    assert_equal "8 gallons", item.reload.quantity
    assert item.acquired?
  end

  test "save_with an invalid item saves nothing, not even the tick" do
    item = go_bag_items(:flashlight)
    item.name = ""

    assert_not item.save_with(have: true, by: users(:spouse))

    assert_not GoBag::Item::Acquisition.exists?(item:)
  end

  test "a category from another household is invalid" do
    item = @bag.items.new(name: "Duct tape", category: go_bag_categories(:outsiders_tools))

    assert_not item.valid?
    assert_includes item.errors[:category], "must be one of the household's categories"
  end

  test "a category that doesn't exist is invalid, not a foreign key error" do
    item = @bag.items.new(name: "Duct tape", category_id: SecureRandom.uuid_v7)

    assert_not item.valid?
    assert_includes item.errors[:category], "must be one of the household's categories"
  end

  test "an item without a bag is invalid, not an error, even with a category" do
    item = GoBag::Item.new(name: "Duct tape", category: go_bag_categories(:water_food))

    assert_not item.valid?
    assert item.errors.added?(:go_bag, :blank)
  end

  test "no category is fine" do
    assert @bag.items.new(name: "Duct tape").valid?
  end

  test "a bag holds at most 200 items" do
    (GoBag::Item::LIMIT - @bag.items.count).times { |i| @bag.items.create!(name: "Item #{i}") }

    item = @bag.items.create(name: "One more")

    assert_not item.persisted?
    assert_includes item.errors[:base], "This bag already has 200 items, the most it can have"
  end

  test "the item limit is checked under the household's lock" do
    assert_queries_match(/FOR UPDATE/) { @bag.items.create!(name: "Whistle") }
  end

  test "an item stays in its bag" do
    assert_raises(ActiveRecord::ReadonlyAttributeError) { go_bag_items(:water).update(go_bag: go_bags(:charlies)) }
  end

  test "an item needs a name" do
    item = @bag.items.new

    assert_not item.valid?
    assert item.errors.added?(:name, :blank)
  end

  test "database: a second acquisition for one item raises RecordNotUnique" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      GoBag::Item::Acquisition.insert!({ item_id: go_bag_items(:water).id, acquired_by_id: users(:head).id })
    end
  end

  test "database: deleting a bag deletes its items and their acquisitions" do
    water = go_bag_items(:water)
    GoBag.where(id: @bag.id).delete_all

    assert_not GoBag::Item.exists?(go_bag_id: @bag.id)
    assert_not GoBag::Item::Acquisition.exists?(item_id: water.id)
  end

  test "removing the item removes its use-by reminders" do
    water = go_bag_items(:water)
    reminder = remind(users(:spouse), about: water)

    water.destroy!

    assert_not Notification.exists?(reminder.id)
  end

  test "deleting the bag removes its items' use-by reminders, and leaves other notifications alone" do
    reminder = remind(users(:spouse), about: go_bag_items(:water))
    other = users(:spouse).notify(kind: "weekly_preview", household: households(:home), subject: households(:home), data: { week_of: "2026-11-23" }, dedupe_key: "weekly_preview:1")

    @bag.destroy!

    assert_not Notification.exists?(reminder.id)
    assert Notification.exists?(other.id)
  end

  private
    def remind(user, about:)
      user.notify(kind: "go_bag_use_by", household: households(:home), subject: about, data: { use_by: "2026-12-20" }, dedupe_key: "go_bag_use_by:#{about.id}:2026-12-20")
    end

    def acquired_item(name, use_by:)
      @bag.items.create!(name:, use_by:).tap { it.acquire(by: users(:spouse)) }
    end
end
