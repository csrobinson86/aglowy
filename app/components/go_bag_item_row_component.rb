# frozen_string_literal: true

# One item on a bag's page (docs/design/go-bags.md, Item rows): its name, cut to two lines, and one muted line joining
# "To buy" when we don't have it, how many, where it's kept, and its use-by date: in the attention color when it's
# soon, and "expired Nov 20" in the danger color once it has passed. read_only is the row as a child sees it (frame
# go-bag-child.png): an icon for "We have it" or "Still to get", "Still to get" instead of "To buy", and no colors.
class GoBagItemRowComponent < ApplicationComponent
  Part = Data.define(:text, :color)

  attr_reader :item, :today

  # today: the household's (household.today).
  def initialize(item:, today:, read_only: false)
    @item = item
    @today = today
    @read_only = read_only
  end

  def read_only?
    @read_only
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
