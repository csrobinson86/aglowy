# Ticking and unticking "we have it" from an item's row, for heads and adults (docs/design/go-bags.md, Item rows). It
# saves straight away and is safe to repeat. Answers with Turbo Streams: the row, the ready box and the tabs, on the tab
# it was ticked on (show). Ticking authorizes the item with update?.
class GoBags::Items::AcquisitionsController < ApplicationController
  include HouseholdScoped

  before_action :set_item

  def create
    @item.acquire(by: Current.user)
    render_changes
  end

  def destroy
    @item.unacquire
    render_changes
  end

  private
    # Through Current.household, then the bag, so another household's bag, or another bag's item, is a 404.
    def set_item
      @item = Current.household.go_bags.find(params[:go_bag_id]).items.find(params[:item_id])
      authorize @item, :update?
    end

    # The bag again, preloaded, so its counts are as they are now without a query per item.
    def render_changes
      @go_bag = Current.household.go_bags.preloaded.find(@item.go_bag_id)
      @item = @go_bag.items.find { it.id == @item.id }
      @show = params[:show].presence_in(GoBag::SHOWS)
      render :changes
    end
end
