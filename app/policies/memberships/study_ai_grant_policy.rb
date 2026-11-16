# Turning personal study with AI on or off for a child: heads of the child's household only
# (docs/design/personal-study.md, Children). The record is the child's membership.
class Memberships::StudyAiGrantPolicy < ApplicationPolicy
  def create?  = head? && record.household_id == membership.household_id
  def destroy? = create?
end
