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
  # Its use-by reminders (docs/design/go-bags.md, The use-by reminder). Removing the bag takes them too (GoBag).
  has_many :notifications, as: :subject, dependent: :delete_all
  # Before the delete_all above, so each person's counter refreshes too.
  before_destroy :withdraw_use_by_reminders, prepend: true

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
  # What the use-by reminder is for: items we have whose date is from today to SOON later. A date already past gets none.
  scope :use_by_reminder_due, ->(today) { acquired.where(use_by: today..today + SOON) }

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

  def use_by_reminder_due?(today)
    acquired? && use_by.present? && use_by.between?(today, today + SOON)
  end

  # create_or_find_by! on the unique index, so two adults ticking at once leave one record, the first one's.
  def acquire(by:)
    Acquisition.create_with(acquired_by: by).create_or_find_by!(item: self).tap do
      reset_acquisition
      remind_about_use_by_later
    end
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

      if have.nil? then remind_about_use_by_later
      elsif ActiveModel::Type::Boolean.new.cast(have) then acquire(by:)
      else unacquire
      end
      true
    end
  end

  # Right away when it's saved or ticked with a date already inside the month, once that commits: otherwise a date set
  # for today after the 8 AM run would never get its reminder. The same dedupe key means the daily job finds it sent.
  def remind_about_use_by_later
    return unless use_by_reminder_due?(household.today)

    ActiveRecord.after_all_transactions_commit { GoBag::Item::UseByReminderJob.perform_later(self) }
  end

  # The reminder for the item's date, to each of the household's active heads and adults, once for each date. Reread
  # under its lock, and "we have it" under one too, both held until the notifications are in, so a removal, an untick
  # or a new date either comes first and leaves nothing to send, or waits (and a removal takes them).
  def remind_about_use_by_now
    transaction do
      lock!
      today = household.today
      next unless use_by&.between?(today, today + SOON) && Acquisition.lock.exists?(item_id: id)

      household.memberships.active.where(role: %w[ head adult ]).includes(:user).each do |membership|
        membership.user.notify(kind: "go_bag_use_by", household:, subject: self, data: { use_by: use_by.iso8601 },
                               dedupe_key: "go_bag_use_by:#{id}:#{use_by.iso8601}")
      end
    end
  rescue ActiveRecord::RecordNotFound
    # Removed since the reminder was asked for: there's nothing to replace.
  end

  private
    # Locked first, so a reminder being made (remind_about_use_by_now) commits before its notifications are withdrawn.
    def withdraw_use_by_reminders
      lock!
      notifications.withdraw
    end

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
