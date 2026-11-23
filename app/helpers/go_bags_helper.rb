module GoBagsHelper
  # The muted line under a bag's title: where it's kept, then who it's for, or for a child, who looks after it
  # (docs/design/go-bags.md, A bag).
  def go_bag_meta_line(go_bag, read_only:)
    whose = if read_only then "The adults keep it up to date"
    elsif go_bag.for_user then "For #{go_bag.for_user.first_name}"
    else "For everyone"
    end
    [ go_bag_kept_at(go_bag), whose ].compact.join(" · ")
  end

  # "Kept in the hall closet", or nil when no one has said where.
  def go_bag_kept_at(go_bag)
    "Kept in #{go_bag.kept_at}" if go_bag.kept_at.present?
  end

  # The To buy card's second line: "Across 3 bags · 2 need replacing soon", without the second part when nothing needs
  # replacing (docs/design/go-bags.md, Go bags).
  def go_bags_to_buy_line(shopping_list)
    replacing = shopping_list.replacing_count
    [ "Across #{pluralize(shopping_list.go_bags.size, "bag")}",
      ("#{replacing} #{replacing == 1 ? "needs" : "need"} replacing soon" if replacing.positive?) ].compact.join(" · ")
  end

  # A category's muted line on Settings → Go bags: "9 items in 2 bags", from GoBag::Category.with_items_counts.
  def go_bag_category_contents(category)
    return "No items" if category.items_count.zero?

    "#{pluralize(category.items_count, "item")} in #{pluralize(category.bags_count, "bag")}"
  end

  # What deleting a category does to its items, in its Delete dialog (docs/design/go-bags.md, Settings → Go bags).
  def go_bag_category_delete_line(category)
    count = category.items_count
    if count.zero? then "It has no items."
    elsif count == 1 then "Its 1 item stays in its bag, under No category."
    else "Its #{count} items stay in their #{category.bags_count == 1 ? "bag" : "bags"}, under No category."
    end
  end
end
