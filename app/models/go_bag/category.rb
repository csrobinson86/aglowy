# One of the household's go-bag categories, shared by all its bags and listed by position (docs/design/go-bags.md,
# GoBag::Category). One made from the suggestions keeps its suggestion_key, so later bags find it after a rename.
class GoBag::Category < ApplicationRecord
  LIMIT = 50

  belongs_to :household
  # A category never moves house, so the household's limit and positions hold.
  attr_readonly :household_id
  # Deleting a category keeps its items: the database sets their category_id to null (on_delete: :nullify).
  has_many :items, class_name: "GoBag::Item"

  encrypts :name

  validates :name, presence: true, length: { maximum: 40 }
  validate :within_the_limit, on: :create

  # Each with items_count and bags_count, the items in it across the household's bags, for Settings → Go bags.
  scope :with_items_counts, -> do
    left_joins(:items).group(:id)
      .select("go_bag_categories.*", "COUNT(go_bag_items.id) AS items_count", "COUNT(DISTINCT go_bag_items.go_bag_id) AS bags_count")
  end

  private
    # Behind the household's lock, which save's transaction holds until the row is in, so two categories added at once
    # can't both be the 50th, nor take the same position. A new category goes last.
    def within_the_limit
      return unless household

      household.lock!
      categories = household.go_bag_categories
      errors.add(:base, "The household already has #{LIMIT} go-bag categories, the most it can have") if categories.count >= LIMIT
      self.position = categories.maximum(:position).to_i + 1
    end
end
