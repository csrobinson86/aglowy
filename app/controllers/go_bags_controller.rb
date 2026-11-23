# Go bags: every member sees the household's bags and what's in them; heads and adults make, edit and delete them
# (docs/design/go-bags.md, Pages). Bags are found through Current.household, so another household's is a 404.
class GoBagsController < ApplicationController
  include HouseholdScoped

  before_action :set_go_bag, only: %i[ show edit update destroy ]
  before_action :set_members, only: %i[ new create edit update ]

  def index
    authorize GoBag
    @go_bags = Current.household.go_bags.preloaded
    # The To buy card, for heads and adults, counted from the same bags as their rows.
    @shopping_list = GoBag::ShoppingList.new(@go_bags, today: Current.household.today) if policy(GoBag).shopping_list?
  end

  # show: the tab, To buy or Use by soon; All when it's neither. Children have no tabs and see every item.
  def show
    authorize @go_bag
    @show = params[:show].presence_in(GoBag::SHOWS) if policy(@go_bag).update?
  end

  # Start with suggested items is ticked for the household's first bag.
  def new
    @suggested = Current.household.go_bags.none?
    @go_bag = Current.household.go_bags.new
    authorize @go_bag
  end

  def create
    authorize GoBag
    @suggested = params.dig(:go_bag, :suggested) == "1"
    @go_bag = Current.household.go_bags.create_with_suggestions(go_bag_params, suggested: @suggested, by: Current.user)

    if @go_bag.persisted?
      redirect_to household_go_bag_path(id: @go_bag), notice: "Go bag created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @go_bag
  end

  def update
    authorize @go_bag

    if @go_bag.update(go_bag_params)
      redirect_to household_go_bag_path(id: @go_bag), notice: "Go bag updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Its items and their acquisitions go with it.
  def destroy
    authorize @go_bag
    @go_bag.destroy!
    redirect_to household_go_bags_path, notice: "Go bag deleted."
  end

  private
    def set_go_bag
      @go_bag = Current.household.go_bags.preloaded.find(params[:id])
    end

    # Who a bag can be for, in the form's For.
    def set_members
      @members = Current.household.active_memberships.includes(:user).map(&:user)
    end

    def go_bag_params
      params.expect(go_bag: %i[ name kept_at for_user_id ])
    end
end
