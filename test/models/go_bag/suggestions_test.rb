require "test_helper"

# The suggested items for a new bag, in Aglowy's own words, and the guide's title and link
# (docs/design/go-bags.md, GoBag::Suggestions).
class GoBag::SuggestionsTest < ActiveSupport::TestCase
  setup do
    @suggestions = GoBag::Suggestions.new
  end

  test "the file loads the nine categories" do
    assert_equal %w[ water_food light_power first_aid documents_money clothing_shelter tools hygiene children worship ], @suggestions.categories.map(&:key)
  end

  test "every category has a unique key, a name and at least one item" do
    assert_equal @suggestions.categories.size, @suggestions.categories.map(&:key).uniq.size

    @suggestions.categories.each do |category|
      assert category.name.present?, "expected #{category.key} to have a name"
      assert_not_empty category.items, "expected #{category.key} to have items"
      assert category.items.all? { it.name.present? }, "expected every item in #{category.key} to have a name"
    end
  end

  test "an item's quantity is optional" do
    water_food = @suggestions.categories.first

    assert_equal "1 gallon a person a day, for 3 days", water_food.items.first.quantity
    assert_nil water_food.items.find { it.name == "Can opener" }.quantity
  end

  test "the guide is a title and a link on wol.jw.org" do
    guide = @suggestions.guide

    assert_equal "When Disaster Strikes—Steps That Can Save Lives", guide.title
    assert_equal "Awake! 2017 No. 5", guide.publication
    uri = URI.parse(guide.url)
    assert_equal "https", uri.scheme
    assert_equal "wol.jw.org", uri.host
  end
end
