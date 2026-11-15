class Membership < ApplicationRecord
  belongs_to :household
  belongs_to :user

  enum :role, %i[ head adult child ].index_by(&:itself), default: :adult, validate: true

  scope :active, -> { where(active: true) }
  scope :preloaded, -> { includes(user: :identity) }
  scope :by_role, -> { in_order_of(:role, roles.keys).order(:created_at) }
  scope :by_household_name, -> { includes(:household).order("households.name") }

  def sole_head?
    head? && active? && household.memberships.active.head.where.not(id: id).none?
  end

  # This week's Monday, in the person's own time zone when they've set one, else the household's.
  def this_week
    Time.current.in_time_zone(user.time_zone.presence || household.time_zone).to_date.beginning_of_week(:monday)
  end

  # Leaving ends the person's meeting-note shares here for good, so rejoining never brings them back
  # (docs/design/meeting-notes.md, "Leaving ends a share for good"), and takes them off the steps not yet
  # done in the household's goals (docs/design/goals.md, "Leaving a household").
  def deactivate
    without_losing_last_head(leaves_headship: true) do
      update(active: false).tap do |deactivated|
        if deactivated
          user.stop_sharing_meeting_notes_with(household)
          user.leave_open_goal_steps_in(household)
        end
      end
    end
  end

  def change_role(role)
    without_losing_last_head(leaves_headship: role.to_s != "head") { update(role: role) }
  end

  private

  # Locks the household so two heads can't demote each other at the same moment (gotcha 5), then reads this
  # seat again: every change to a seat takes the same lock, so a copy loaded before a promotion can't slip past.
  def without_losing_last_head(leaves_headship:)
    transaction do
      household.lock!
      reload

      if leaves_headship && sole_head?
        errors.add(:base, "A household needs at least one active head")
        false
      else
        yield
      end
    end
  end
end
