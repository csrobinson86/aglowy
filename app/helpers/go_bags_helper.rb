module GoBagsHelper
  # The muted line under a bag's title: where it's kept, then who it's for, or for a child, who looks after it
  # (docs/design/go-bags.md, A bag).
  def go_bag_meta_line(go_bag, read_only:)
    whose = if read_only then "The adults keep it up to date"
    elsif go_bag.for_user then "For #{go_bag.for_user.first_name}"
    else "For everyone"
    end
    [ ("Kept in #{go_bag.kept_at}" if go_bag.kept_at.present?), whose ].compact.join(" · ")
  end
end
