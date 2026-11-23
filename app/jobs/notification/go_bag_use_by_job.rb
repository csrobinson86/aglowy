# Each household where it's the 8 AM hour reminds its heads and adults about the go-bag items to replace within a month
# (docs/design/go-bags.md, The use-by reminder). Hourly, so every zone has its 8 AM; safe to run twice.
class Notification::GoBagUseByJob < ApplicationJob
  def perform
    Household.at_local_hour(8).find_each(&:remind_about_go_bag_use_by)
  end
end
