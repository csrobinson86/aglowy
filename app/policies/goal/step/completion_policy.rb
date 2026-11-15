# Ticking and unticking a goal's steps while the goal is open (docs/design/goals.md, Who can do what).
# Family goals: heads and adults tick any Everyone step and anyone's part, because children don't need a login.
# A child ticks only their own part of a step naming them, whatever user_id they post.
# Personal goals: only the owner, whatever their role, and only done together (no user_id).
# Goal::Step#tick and #untick recheck openness under the goal's lock.
class Goal::Step::CompletionPolicy < ApplicationPolicy
  def create?  = goal.open? && (goal.family? ? family_tick? : owners_tick?)
  def destroy? = create?

  private

  def goal
    record.step.goal
  end

  def family_tick?
    member_here? && (head_or_adult? || own_part?)
  end

  def owners_tick?
    record.user_id.nil? && GoalPolicy.new(membership, goal).update?
  end

  def member_here?
    member? && membership.household_id == goal.household_id
  end

  def own_part?
    record.user_id == membership.user_id && membership.user_id.in?(record.step.parts)
  end
end
