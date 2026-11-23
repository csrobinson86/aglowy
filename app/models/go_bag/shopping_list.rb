# What's to buy across a household's bags (docs/design/go-bags.md, To buy and Words): the To buy page, and the card on
# Go bags. Every count goes through GoBag::Item#to_buy?, as a bag's "4 to buy" does, so they all agree. Pass bags from
# GoBag.preloaded, so it counts without a query per item.
class GoBag::ShoppingList
  attr_reader :today

  # today: the household's (household.today).
  def initialize(go_bags, today:)
    @all_go_bags = go_bags
    @today = today
  end

  # The bags with something to buy, in the order they were made.
  def go_bags
    @go_bags ||= @all_go_bags.select { it.to_buy_count(today).positive? }
  end

  # A bag's things to get, then its things to replace, each in the order they were added (frame go-bags-to-buy.png).
  def items_in(go_bag)
    go_bag.items_to_buy(today).partition(&:to_get?).flatten
  end

  def items_count
    go_bags.sum { it.to_buy_count(today) }
  end

  def replacing_count
    go_bags.sum { it.use_by_soon_count(today) }
  end

  def empty?
    go_bags.empty?
  end
end
