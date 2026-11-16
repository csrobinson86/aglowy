# A head's read-only view of a child's personal studies (docs/design/personal-study.md, Children). The record is the
# child's membership: the viewer is a head here, and the child is active here with a study AI grant. Only this
# household's grant counts (Traps: grants are per membership).
class ChildStudyPolicy < ApplicationPolicy
  def index? = show?

  def show?
    head? && record.household_id == membership.household_id && record.active? && record.child? && record.study_ai_grant?
  end
end
