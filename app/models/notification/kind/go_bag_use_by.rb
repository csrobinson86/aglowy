# "Bottled water in Family go bag: use by December 20": an item we have whose use-by date is a month away or less, for
# the household's heads and adults (docs/design/go-bags.md, The use-by reminder). The names come from the item when it's
# shown, the date from the notification, so after the date changes an older reminder still says the date it was sent
# for. It opens the item's page, and its email waits for the daily summary.
class Notification::Kind::GoBagUseBy < Notification::Kind
  def icon = :briefcase
  def color = :yellow
  def email = :summary
  def label = "Go bag use-by dates"
  def description = "A month before something in a go bag needs replacing. Heads and adults."

  # Heads and adults keep the bags up to date.
  def offered_to?(user)
    user.memberships.active.where(role: %w[ head adult ]).exists?
  end

  def title
    "#{subject.name} in #{subject.go_bag.name}: use by #{use_by.strftime("%B %-d")}"
  end

  def body
    "Replace it, then set the new use-by date."
  end

  def target_path
    edit_household_go_bag_item_path(household_id:, go_bag_id: subject.go_bag_id, id: subject)
  end

  private
    def use_by
      Date.parse(notification.data.fetch("use_by"))
    end
end
