# Adding, changing and removing a bag's items, for heads and adults (docs/design/go-bags.md, An item). Opened from a row
# or "+ Add item" it's a dialog loaded into the bag page's Turbo Frame, and a save closes it and refreshes the page.
# Opened directly, as from a notification, it's a page, and a save goes back to the bag. The bag is found through
# Current.household and the item through the bag, so another household's bag, or another bag's item, is a 404.
class GoBags::ItemsController < ApplicationController
  include HouseholdScoped

  before_action :set_go_bag
  before_action :set_item, only: %i[ edit update destroy ]

  helper_method :have?

  # With the category of the section whose "+ Add item" opened it; one from another household chooses No category.
  def new
    @item = @go_bag.items.new(category: Current.household.go_bag_categories.find_by(id: params[:category_id]))
    authorize @item
  end

  # A category_id from another household is a validation error on the item, never saved.
  def create
    @item = @go_bag.items.new(item_params)
    authorize @item

    if @item.save_with(have: have_param, by: Current.user)
      close_dialog_or_go_to_bag
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @item.assign_attributes(item_params)

    if @item.save_with(have: have_param, by: Current.user)
      close_dialog_or_go_to_bag
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Without a second question, since an item is quick to add back.
  def destroy
    @item.destroy!
    close_dialog_or_go_to_bag
  end

  private
    def set_go_bag
      @go_bag = Current.household.go_bags.find(params[:go_bag_id])
    end

    def set_item
      @item = @go_bag.items.find(params[:id])
      authorize @item
    end

    def item_params
      params.expect(go_bag_item: %i[ name category_id quantity use_by stored_at ])
    end

    # The form's "We have it" box, saved with the item by GoBag::Item#save_with.
    def have_param
      params.dig(:go_bag_item, :have)
    end

    # Whether the form shows "We have it" ticked: as the item is, or as it was sent when the save was refused.
    def have?
      have_param.nil? ? @item.acquired? : ActiveModel::Type::Boolean.new.cast(have_param)
    end

    def close_dialog_or_go_to_bag
      if turbo_frame_request?
        render :saved, formats: :turbo_stream
      else
        redirect_to household_go_bag_path(id: @go_bag), status: :see_other
      end
    end
end
