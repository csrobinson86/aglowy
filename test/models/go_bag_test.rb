require "test_helper"

# A household's go bags (docs/design/go-bags.md, GoBag and GoBag::Suggestions).
class GoBagTest < ActiveSupport::TestCase
  setup do
    @household = households(:home)
  end

  test "a household has at most 20 bags" do
    18.times { |i| @household.go_bags.create!(name: "Bag #{i}", created_by: users(:spouse)) }
    assert_equal 20, @household.go_bags.count

    bag = @household.go_bags.create(name: "One more", created_by: users(:spouse))

    assert_not bag.persisted?
    assert_includes bag.errors[:base], "The household already has 20 go bags, the most it can have"
  end

  test "the bag limit is checked under the household's lock" do
    assert_queries_match(/FOR UPDATE/) { @household.go_bags.create!(name: "Car kit", created_by: users(:spouse)) }
  end

  test "a bag needs a name" do
    bag = @household.go_bags.new(created_by: users(:spouse))

    assert_not bag.valid?
    assert bag.errors.added?(:name, :blank)
  end

  test "a bag can be for an active member of the household, or for everyone" do
    assert @household.go_bags.new(name: "Eli's bag", for_user: users(:eli), created_by: users(:spouse)).valid?
    assert @household.go_bags.new(name: "Car kit", created_by: users(:spouse)).valid?
  end

  test "a bag can't be for someone who left the household or was never in it" do
    [ users(:former), users(:outsider) ].each do |user|
      bag = @household.go_bags.new(name: "Their bag", for_user: user, created_by: users(:spouse))

      assert_not bag.valid?, "expected a bag for #{user.name} to be refused"
      assert_includes bag.errors[:for_user], "must be an active member of the household"
    end
  end

  test "who a bag is for is checked under the household's lock" do
    bag = go_bags(:family)

    assert_queries_match(/FOR UPDATE/) { bag.update!(for_user: users(:eli)) }
  end

  test "create_with_suggestions without suggestions makes an empty bag" do
    bag = nil

    assert_no_difference -> { GoBag::Category.count } do
      bag = @household.go_bags.create_with_suggestions({ name: "Car kit", kept_at: "the trunk" }, suggested: false, by: users(:spouse))
    end

    assert bag.persisted?
    assert_equal users(:spouse), bag.created_by
    assert_empty bag.items
  end

  test "create_with_suggestions adds every suggested item to get, reusing the household's suggested categories by key" do
    suggestions = GoBag::Suggestions.new
    go_bag_categories(:water_food).update!(name: "Drinks and snacks")

    bag = assert_difference -> { @household.go_bag_categories.count }, suggestions.categories.size - 2 do
      @household.go_bags.create_with_suggestions({ name: "Grab bag" }, suggested: true, by: users(:spouse))
    end

    assert_equal suggestions.categories.sum { it.items.size }, bag.items.count
    assert_equal bag.items.count, bag.items.to_get.count
    assert_equal go_bag_categories(:water_food), bag.items.find { it.name == "Can opener" }.category
    assert_equal "1 gallon a person a day, for 3 days", bag.items.find { it.name == "Bottled water" }.quantity
    assert_equal suggestions.categories.map(&:key), @household.go_bag_categories.where.not(suggestion_key: nil).order(:position).pluck(:suggestion_key)
  end

  test "a second bag from the suggestions makes no new categories" do
    @household.go_bags.create_with_suggestions({ name: "Grab bag" }, suggested: true, by: users(:spouse))

    assert_no_difference -> { GoBag::Category.count } do
      @household.go_bags.create_with_suggestions({ name: "Car kit" }, suggested: true, by: users(:spouse))
    end
  end

  test "a deleted suggested category is made again, last" do
    go_bag_categories(:water_food).destroy!
    @household.go_bags.create_with_suggestions({ name: "Grab bag" }, suggested: true, by: users(:spouse))

    remade = @household.go_bag_categories.find_by!(suggestion_key: "water_food")
    assert_equal "Water and food", remade.name
    assert_operator remade.position, :>, go_bag_categories(:light_power).position
  end

  test "create_with_suggestions saves nothing when the bag is invalid" do
    bag = nil

    assert_no_difference [ -> { GoBag.count }, -> { GoBag::Category.count }, -> { GoBag::Item.count } ] do
      bag = @household.go_bags.create_with_suggestions({ name: "" }, suggested: true, by: users(:spouse))
    end

    assert_not bag.persisted?
    assert bag.errors.added?(:name, :blank)
  end

  test "create_with_suggestions saves nothing when the suggested categories don't fit" do
    (GoBag::Category::LIMIT - 2).times { |i| @household.go_bag_categories.create!(name: "Category #{i}") }
    bag = nil

    assert_no_difference [ -> { GoBag.count }, -> { GoBag::Category.count }, -> { GoBag::Item.count } ] do
      bag = @household.go_bags.create_with_suggestions({ name: "Grab bag" }, suggested: true, by: users(:spouse))
    end

    assert_not bag.persisted?
    assert_includes bag.errors[:base], "The household already has 50 go-bag categories, the most it can have"
  end

  test "create_with_suggestions inside a caller's transaction still saves nothing when the categories don't fit" do
    (GoBag::Category::LIMIT - 2).times { |i| @household.go_bag_categories.create!(name: "Category #{i}") }
    saved = nil

    assert_no_difference [ -> { GoBag.count }, -> { GoBag::Category.count }, -> { GoBag::Item.count } ] do
      GoBag.transaction { saved = @household.go_bags.create_with_suggestions({ name: "Grab bag" }, suggested: true, by: users(:spouse)).persisted? }
    end

    assert_not saved
  end

  test "a bag stays in its household" do
    assert_raises(ActiveRecord::ReadonlyAttributeError) { go_bags(:family).update(household: households(:other)) }
  end

  test "counts come from preloaded items without a query per item" do
    bags = assert_queries_count(4) { @household.go_bags.preloaded.to_a }
    family = bags.find { it == go_bags(:family) }
    today = Date.new(2026, 11, 23)

    assert_queries_count(0) do
      assert_equal 3, family.items_count
      assert_equal 2, family.ready_count
      assert_equal 1, family.to_buy_count(today)
    end
  end
end
