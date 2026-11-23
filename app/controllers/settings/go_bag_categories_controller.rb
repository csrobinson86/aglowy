# Settings → Go bags: the household's go-bag categories, added, renamed and deleted by heads and adults
# (docs/design/go-bags.md, Pages). Rename and Add category load this page with ?rename= or ?add= into the row's Turbo
# Frame, so there are no new and edit pages. Categories are found through Current.household, so another's is a 404.
class Settings::GoBagCategoriesController < ApplicationController
  include HouseholdScoped

  before_action :set_category, only: %i[ update destroy ]
  before_action :set_categories, except: :destroy

  def index
    authorize GoBag::Category
    @renaming = Current.household.go_bag_categories.find(params[:rename]) if params[:rename]
    @adding = Current.household.go_bag_categories.new if params[:add]
  end

  def create
    authorize GoBag::Category
    @adding = Current.household.go_bag_categories.new(category_params)

    if @adding.save
      redirect_to household_settings_go_bag_categories_path, notice: "Category added."
    else
      render :index, status: :unprocessable_content
    end
  end

  def update
    authorize @category

    if @category.update(category_params)
      redirect_to household_settings_go_bag_categories_path, notice: "Category renamed."
    else
      @renaming = @category
      render :index, status: :unprocessable_content
    end
  end

  # Its items stay in their bags, under No category (go_bag_items.category_id is on_delete: :nullify).
  def destroy
    authorize @category
    @category.destroy!
    redirect_to household_settings_go_bag_categories_path, notice: "Category deleted."
  end

  private
    def set_category
      @category = Current.household.go_bag_categories.find(params[:id])
    end

    def set_categories
      @categories = Current.household.go_bag_categories.with_items_counts
    end

    def category_params
      params.expect(go_bag_category: [ :name ])
    end
end
