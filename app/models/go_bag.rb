# One of a household's emergency bags, with what's in it (docs/design/go-bags.md, GoBag). Its text is encrypted, so
# bags are listed by id, the order they were made, never by name.
class GoBag < ApplicationRecord
  LIMIT = 20
  # The bag page's tabs after All (docs/design/go-bags.md, A bag).
  SHOWS = %w[ to_buy use_by_soon ]

  belongs_to :household
  # A bag never moves house, so the household's limits and categories hold.
  attr_readonly :household_id
  # Nil means it's for everyone. Membership#deactivate clears it when that person leaves.
  belongs_to :for_user, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User"
  # The database takes their acquisitions with them (on_delete: :cascade).
  has_many :items, -> { order(:id) }, dependent: :delete_all, inverse_of: :go_bag

  encrypts :name, :kept_at

  validates :name, presence: true, length: { maximum: 80 }
  validates :kept_at, length: { maximum: 80 }
  validate :within_the_limit, on: :create
  validate :for_an_active_member, if: -> { for_user_id && will_save_change_to_for_user_id? }

  scope :preloaded, -> { includes(items: %i[ acquisition category ]) }
  # The bags with something to buy as of today, the household's (docs/design/go-bags.md, To buy).
  scope :with_items_to_buy, ->(today) { where(id: GoBag::Item.to_buy(today).select(:go_bag_id)) }

  # Called on a household's bags: household.go_bags.create_with_suggestions(attributes, suggested: true, by: user).
  def self.create_with_suggestions(attributes, suggested:, by:)
    new(attributes).tap do |bag|
      bag.created_by = by
      bag.save_with_suggestions(suggested:)
    end
  end

  # With suggested, the suggested items go in too, none of them acquired, each in the household's category for its
  # suggestion_key, made last when it's missing. All in one transaction under the household's lock, so two bags made
  # at once can't both make a missing category, and a household whose categories are full saves nothing at all
  # (docs/design/go-bags.md, GoBag::Suggestions). Its own savepoint, so that holds inside a caller's transaction too.
  def save_with_suggestions(suggested:)
    transaction(requires_new: true) do
      household&.lock!
      raise ActiveRecord::Rollback unless save

      add_suggested_items if suggested
      true
    rescue ActiveRecord::RecordInvalid => error
      errors.merge!(error.record)
      raise ActiveRecord::Rollback
    end || false
  end

  # These count the loaded items, so a list of GoBag.preloaded asks nothing more.
  def items_count
    items.size
  end

  def ready_count
    items.count(&:acquired?)
  end

  def ready_percent
    items_count.zero? ? 0 : (100.0 * ready_count / items_count).round
  end

  def items_to_buy(today)
    items.select { it.to_buy?(today) }
  end

  def to_buy_count(today)
    items_to_buy(today).size
  end

  def use_by_soon_count(today)
    items.count { it.use_by_soon?(today) }
  end

  # The loaded items grouped by category, in the categories' order, with No category (nil) last
  # (docs/design/go-bags.md, GoBag::Item). Within a group they keep the order they were added. show, one of SHOWS,
  # keeps only the items to buy or to use soon, as of today; nil keeps them all.
  def items_by_category(show: nil, today: nil)
    shown = case show
    when "to_buy" then items_to_buy(today)
    when "use_by_soon" then items.select { it.use_by_soon?(today) }
    else items
    end
    shown.group_by(&:category).sort_by { |category, _| category ? [ 0, category.position ] : [ 1, 0 ] }
  end

  private
    def add_suggested_items
      GoBag::Suggestions.new.categories.each do |suggested|
        category = household.go_bag_categories.find_by(suggestion_key: suggested.key) ||
          household.go_bag_categories.create!(name: suggested.name, suggestion_key: suggested.key)
        suggested.items.each { items.create!(name: it.name, quantity: it.quantity, category:) }
      end
    end

    # Behind the household's lock, which save's transaction holds until the row is in, so two bags made at once can't
    # both be the 20th.
    def within_the_limit
      return unless household

      household.lock!
      errors.add(:base, "The household already has #{LIMIT} go bags, the most it can have") if household.go_bags.count >= LIMIT
    end

    # Behind the lock Membership#deactivate takes, so the person can't leave between this check and the save.
    def for_an_active_member
      return unless household

      household.lock!
      errors.add(:for_user, "must be an active member of the household") unless household.memberships.active.exists?(user_id: for_user_id)
    end
end
