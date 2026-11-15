# Whoever may change the goal may add, edit and remove its steps, while it's open (docs/design/goals.md,
# Who can do what). The step's model methods recheck openness under the goal's lock.
class Goal::StepPolicy < ApplicationPolicy
  def create?  = record.goal.open? && GoalPolicy.new(membership, record.goal).update?
  def update?  = create?
  def destroy? = create?
end
