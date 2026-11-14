class Membership < ApplicationRecord
  belongs_to :household
  belongs_to :user

  enum :role, %i[ head adult child ].index_by(&:itself), default: :adult, validate: true

  scope :active, -> { where(active: true) }
  scope :preloaded, -> { includes(:user) }
  scope :by_role, -> { in_order_of(:role, roles.keys).order(:created_at) }
  scope :by_household_name, -> { includes(:household).order("households.name") }

  def sole_head?
    head? && active? && household.memberships.active.head.where.not(id: id).none?
  end

  def deactivate
    without_losing_last_head(leaves_headship: true) { update(active: false) }
  end

  def change_role(role)
    without_losing_last_head(leaves_headship: role.to_s != "head") { update(role: role) }
  end

  private

  # Locks the household so two heads can't demote each other at the same moment (gotcha 5).
  def without_losing_last_head(leaves_headship:)
    transaction do
      household.lock!

      if leaves_headship && sole_head?
        errors.add(:base, "A household needs at least one active head")
        false
      else
        yield
      end
    end
  end
end
