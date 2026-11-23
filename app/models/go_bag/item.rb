# A thing in a go bag (docs/design/go-bags.md, GoBag::Item and Words). Ready means we have it, in the bag or kept
# somewhere else; to buy means still to get, or use by soon. Every count of "to buy" goes through to_buy and to_buy?.
class GoBag::Item < ApplicationRecord
  LIMIT = 200
  SOON = 30.days

  belongs_to :go_bag
  # An item never moves bag, so the bag's limit holds.
  attr_readonly :go_bag_id
  # Nil is No category.
  belongs_to :category, class_name: "GoBag::Category", optional: true
  has_one :acquisition, dependent: :delete

  encrypts :name, :quantity, :stored_at

  delegate :household, to: :go_bag

  validates :name, presence: true, length: { maximum: 100 }
  validates :quantity, length: { maximum: 40 }
  validates :stored_at, length: { maximum: 80 }
  # On the id, so one that doesn't exist (deleted while the form was open) is refused here, not by the foreign key.
  validate :category_in_household, if: -> { category_id && go_bag }
  validate :within_the_limit, on: :create

  scope :acquired, -> { where.associated(:acquisition) }
  scope :to_get, -> { where.missing(:acquisition) }
  # "Today" is the household's (household.today), never the server's date.
  scope :use_by_soon, ->(today) { acquired.where(use_by: ..today + SOON) }
  # An item to get is to buy whatever its date, so the second half needn't ask for acquired.
  scope :to_buy, ->(today) { to_get.or(left_outer_joins(:acquisition).where(use_by: ..today + SOON)) }

  def acquired?
    acquisition.present?
  end

  def to_get?
    !acquired?
  end

  def use_by_soon?(today)
    acquired? && use_by.present? && use_by <= today + SOON
  end

  def expired?(today)
    use_by.present? && use_by < today
  end

  def to_buy?(today)
    to_get? || use_by_soon?(today)
  end

  # create_or_find_by! on the unique index, so two adults ticking at once leave one record, the first one's.
  def acquire(by:)
    Acquisition.create_with(acquired_by: by).create_or_find_by!(item: self).tap { reset_acquisition }
  end

  def unacquire
    Acquisition.where(item: self).delete_all
    reset_acquisition
  end

  # The item form's fields and its "We have it" box, saved together or not at all. have is the box's value, "0" or
  # "1" from a form; nil leaves the tick as it was.
  def save_with(have:, by:)
    transaction do
      next false unless save

      ActiveModel::Type::Boolean.new.cast(have) ? acquire(by:) : unacquire unless have.nil?
      true
    end
  end

  private
    def category_in_household
      errors.add(:category, "must be one of the household's categories") unless category&.household_id == go_bag.household_id
    end

    # Behind the household's lock, which save's transaction holds until the row is in, so two items added at once can't
    # both be the 200th.
    def within_the_limit
      return unless go_bag

      household.lock!
      errors.add(:base, "This bag already has #{LIMIT} items, the most it can have") if go_bag.items.count >= LIMIT
    end
end
