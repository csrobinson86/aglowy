# A tick: whose part it is (no user when done together, and on a personal goal's step) and who ticked it.
# Only created through Goal::Step#tick, under the goal's lock, so these checks see the step as it is now.
class Goal::Step::Completion < ApplicationRecord
  belongs_to :step, class_name: "Goal::Step", inverse_of: :completions
  belongs_to :user, optional: true
  belongs_to :completed_by, class_name: "User"

  validate :user_fits_the_step

  private
    def user_fits_the_step
      if step.everyone?
        errors.add(:user, "must be blank on a step for everyone") if user
      elsif !user&.id.in?(step.assignments.map(&:user_id))
        errors.add(:user, "isn't named on this step")
      elsif !step.goal.household.memberships.active.exists?(user: user)
        errors.add(:user, "isn't an active member of the household")
      end
    end
end
