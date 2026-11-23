require "test_helper"

# The household's go-bag categories, shared by all its bags (docs/design/go-bags.md, GoBag::Category).
class GoBag::CategoryTest < ActiveSupport::TestCase
  setup do
    @household = households(:home)
  end

  test "a new category goes last" do
    category = @household.go_bag_categories.create!(name: "For the car")

    assert_equal 3, category.position
    assert_equal category, @household.go_bag_categories.last
  end

  test "the first category in a household is at position 1" do
    assert_equal 1, households(:parents).go_bag_categories.create!(name: "Water").position
  end

  test "a household has at most 50 categories" do
    (GoBag::Category::LIMIT - 2).times { |i| @household.go_bag_categories.create!(name: "Category #{i}") }

    category = @household.go_bag_categories.create(name: "One more")

    assert_not category.persisted?
    assert_includes category.errors[:base], "The household already has 50 go-bag categories, the most it can have"
  end

  test "the limit and the position are worked out under the household's lock" do
    assert_queries_match(/FOR UPDATE/) { @household.go_bag_categories.create!(name: "For the car") }
  end

  test "a category stays in its household" do
    assert_raises(ActiveRecord::ReadonlyAttributeError) { go_bag_categories(:water_food).update(household: households(:other)) }
  end

  test "a category needs a name" do
    category = @household.go_bag_categories.new

    assert_not category.valid?
    assert category.errors.added?(:name, :blank)
  end

  test "destroying a category keeps its items, with no category" do
    go_bag_categories(:water_food).destroy!

    assert_nil go_bag_items(:water).reload.category_id
  end

  test "database: a second category with the same suggestion key in a household raises RecordNotUnique" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      GoBag::Category.insert!({ household_id: @household.id, name: "Water", position: 3, suggestion_key: "water_food" })
    end
  end

  test "database: categories without a suggestion key don't clash" do
    2.times { |i| GoBag::Category.insert!({ household_id: @household.id, name: "Mine #{i}", position: 3 + i }) }

    assert_equal 2, @household.go_bag_categories.where(suggestion_key: nil).count
  end

  test "database: deleting a category sets its items' category to null" do
    GoBag::Category.where(id: go_bag_categories(:water_food).id).delete_all

    assert_nil go_bag_items(:water).reload.category_id
  end

  test "database: a category without a position raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) do
      GoBag::Category.insert!({ household_id: @household.id, name: "Water", position: nil })
    end
  end
end
