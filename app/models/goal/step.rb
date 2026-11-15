# One step towards a goal, for everyone or for named people (docs/design/goals.md, Goal::Step).
# No assignments means Everyone. Every write takes the goal's lock and rereads what it depends on
# behind it, so a tick or an assignment can't slip past a reassignment, a deactivation or an archival.
class Goal::Step < ApplicationRecord
  belongs_to :goal
  has_many :assignments, dependent: :delete_all, inverse_of: :step
  has_many :assignees, through: :assignments, source: :user
  has_many :completions, dependent: :delete_all, inverse_of: :step

  encrypts :title

  validates :title, presence: true

  def everyone?
    assignments.empty?
  end

  # Everyone (or a personal goal's step): a tick with no person. Named people: every one of them has ticked.
  # Answers from loaded records, so a preloaded goal asks no query per step.
  def done?
    everyone? ? ticked_for?(nil) : assigned_user_ids.all? { ticked_for?(it) }
  end

  def done_for?(user)
    everyone? ? ticked_for?(nil) : user.id.in?(assigned_user_ids) && ticked_for?(user.id)
  end

  # An empty list means Everyone. Assignments that stay are kept; every assignee is rechecked as an active
  # member under the lock, and ticks that no longer fit are deleted (docs/design/goals.md, "Changing who a step is for").
  def reassign(to:)
    goal.under_lock do
      assignments.where.not(user: to).delete_all
      to.uniq.each { assignments.find_or_initialize_by(user: it).save! }
      delete_ticks_that_no_longer_fit(to.map(&:id))
    end
  ensure
    assignments.reset
    completions.reset
  end

  # A person's part of a named step, or nil for done together. Ticking twice is a no-op. The completion's
  # validations recheck, behind the lock, that the person is still named and still an active member.
  # (`for` is a keyword, so it's read through the binding.)
  def tick(for:, by:)
    user = binding.local_variable_get(:for)

    goal.under_lock do
      goal.require_open!
      assignments.reset
      completions.find_by(user: user) || completions.create!(user: user, completed_by: by)
    end
  ensure
    completions.reset
  end

  # Nothing is checked about the person whose tick goes, so an adult can always remove a departed member's tick.
  def untick(for:)
    user = binding.local_variable_get(:for)

    goal.under_lock do
      goal.require_open!
      completions.where(user: user).delete_all
    end
  ensure
    completions.reset
  end

  private
    def assigned_user_ids
      assignments.map(&:user_id)
    end

    def ticked_for?(user_id)
      completions.any? { it.user_id == user_id }
    end

    def delete_ticks_that_no_longer_fit(user_ids)
      if user_ids.empty?
        completions.where.not(user_id: nil).delete_all
      else
        completions.where(user_id: nil).or(completions.where.not(user_id: user_ids)).delete_all
      end
    end
end
