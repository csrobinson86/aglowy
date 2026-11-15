# Family goals: every active member of the goal's household sees them; heads and adults set and change them.
# Personal goals: only the owner, through any household they're active in. Sharing comes later
# (docs/design/goals.md, Who can do what).
class GoalPolicy < ApplicationPolicy
  def show?    = record.family? ? member_here? : owner?
  def create?  = record.family? ? head_or_adult_here? : owner?
  def update?  = create?
  def destroy? = create?

  private

  def member_here?
    member? && membership.household_id == record.household_id
  end

  def head_or_adult_here?
    head_or_adult? && member_here?
  end

  def owner?
    member? && membership.user_id == record.user_id
  end
end
