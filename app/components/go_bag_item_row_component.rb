# frozen_string_literal: true

# One item on a bag's page (docs/design/go-bags.md, Item rows): its name, cut to two lines, and one muted line joining
# "To buy" when we don't have it, how many, where it's kept, and its use-by date: in the attention color when it's
# soon, and "expired Nov 20" in the danger color once it has passed. For heads and adults it starts with the "we have
# it" box, which saves as soon as it's ticked, and ends with "›", opening the item's dialog (frame go-bag.png).
# read_only is the row as a child sees it (frame go-bag-child.png): an icon for "We have it" or "Still to get", "Still
# to get" instead of "To buy", no colors, and nothing to press.
class GoBagItemRowComponent < ApplicationComponent
  Part = Data.define(:text, :color)

  attr_reader :item, :today

  # today: the household's (household.today). show: the bag page's tab, kept by the box's form so the redrawn tabs
  # stay on it. focus: the box takes focus, as when a Turbo Stream redraws the row it was just ticked in.
  def initialize(item:, today:, read_only: false, show: nil, focus: false)
    @item = item
    @today = today
    @read_only = read_only
    @show = show
    @focus = focus
  end

  def read_only?
    @read_only
  end

  def focus?
    @focus
  end

  # Ticking posts the acquisition; unticking deletes it.
  def tick_form_options
    { url: household_go_bag_item_acquisition_path(household_id:, go_bag_id: item.go_bag_id, item_id: item, show: @show),
      method: item.acquired? ? :delete : :post, data: { controller: "auto-submit" } }
  end

  def edit_path
    edit_household_go_bag_item_path(household_id:, go_bag_id: item.go_bag_id, id: item)
  end

  # The line's parts, the first one capitalized: "In the bag", "6 gallons · in the bag". There's always one, since an
  # item is either to get or in a place.
  def parts
    first, *rest = [ (Part.new(read_only? ? "Still to get" : "To buy", nil) if item.to_get?),
                     (Part.new(item.quantity, nil) if item.quantity.present?),
                     place,
                     use_by ].compact
    [ first.with(text: first.text.upcase_first), *rest ]
  end

  private
    def household_id
      item.go_bag.household_id
    end

    # Where it's kept when it's somewhere else; "in the bag" once we have it.
    def place
      if item.stored_at.present?
        Part.new("Kept in #{item.stored_at}", nil)
      elsif item.acquired?
        Part.new("in the bag", nil)
      end
    end

    def use_by
      return unless item.use_by

      if item.expired?(today)
        Part.new("expired #{short_date(item.use_by)}", (:danger unless read_only?))
      else
        Part.new("use by #{short_date(item.use_by)}", (:attention if item.use_by_soon?(today) && !read_only?))
      end
    end

    # "Dec 20", with the year when it isn't this one.
    def short_date(date)
      date.strftime(date.year == today.year ? "%b %-d" : "%b %-d, %Y")
    end
end
