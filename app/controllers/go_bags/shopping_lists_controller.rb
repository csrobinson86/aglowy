# To buy: everything still to get and everything to replace soon, across the household's bags, for heads and adults
# (docs/design/go-bags.md, To buy). Ticking a thing posts its acquisition, as a bag's row does
# (GoBags::Items::AcquisitionsController). The bags are found through Current.household, so no other household's show.
class GoBags::ShoppingListsController < ApplicationController
  include HouseholdScoped

  def show
    authorize GoBag, :shopping_list?
    today = Current.household.today
    @shopping_list = GoBag::ShoppingList.new(Current.household.go_bags.with_items_to_buy(today).preloaded, today:)
  end
end
