# Names a person on a step. Only written through Goal#add_step and Goal::Step#reassign, which hold the
# household's lock, so the membership check below is a recheck no deactivation can slip past.
class Goal::Step::Assignment < ApplicationRecord
  belongs_to :step, class_name: "Goal::Step", inverse_of: :assignments
  belongs_to :user

  validate :user_is_an_active_member

  private
    def user_is_an_active_member
      household = step.goal.household

      if household.nil?
        errors.add(:base, "A personal goal's steps are for its owner only")
      elsif !household.memberships.active.exists?(user: user)
        errors.add(:user, "must be an active member of the household")
      end
    end
end
