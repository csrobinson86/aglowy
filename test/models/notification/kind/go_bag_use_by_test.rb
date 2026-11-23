require "test_helper"

# What go_bag_use_by says, opens and who is offered it (docs/design/go-bags.md, The use-by reminder). The item and bag
# names come from the subject when it's shown; the date from the notification's own data.
class Notification::Kind::GoBagUseByTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @household = households(:home)
    @water = go_bag_items(:water)
  end

  test "the wording: the item, its bag and the date it was sent for, then what to do" do
    notification = remind(:spouse, about: @water, use_by: Date.new(2026, 12, 20))

    assert_equal "Bottled water in Family go bag: use by December 20", notification.title
    assert_equal "Replace it, then set the new use-by date.", notification.body
  end

  test "after the item's date changes, the older reminder still shows its own date, and the item's new name" do
    notification = remind(:spouse, about: @water, use_by: Date.new(2026, 12, 20))

    @water.update!(name: "Water bottles", use_by: Date.new(2027, 6, 1))

    assert_equal "Water bottles in Family go bag: use by December 20", notification.reload.title
  end

  test "the target is the item's page under the notification's household" do
    notification = remind(:spouse, about: @water, use_by: Date.new(2026, 12, 20))

    assert_equal edit_household_go_bag_item_path(household_id: @household, go_bag_id: go_bags(:family), id: @water), notification.target_path
  end

  test "the briefcase in yellow, and its email waits for the daily summary" do
    notification = remind(:spouse, about: @water, use_by: Date.new(2026, 12, 20))

    assert_equal [ :briefcase, :yellow, :summary ], [ notification.icon, notification.color, notification.email ]
    assert_includes Notification::Kind.summary_names, "go_bag_use_by"
    assert_equal "Go bag use-by dates", notification.label
  end

  test "offered to a head and an adult, and not to someone who is a child everywhere" do
    kind = Notification::Kind::GoBagUseBy.new(nil)

    assert_equal "go_bag_use_by", kind.name
    assert_equal "A month before something in a go bag needs replacing. Heads and adults.", kind.description
    assert kind.offered_to?(users(:head))
    assert kind.offered_to?(users(:spouse))
    assert_not kind.offered_to?(users(:eli))
  end

  private
    def remind(person, about:, use_by:)
      users(person).notify(kind: "go_bag_use_by", household: @household, subject: about, data: { use_by: use_by.iso8601 },
                           dedupe_key: "go_bag_use_by:#{about.id}:#{use_by.iso8601}")
    end
end
