# Heads and adults, like scheduling a study (docs/design/family-studies.md, AI helper: Who can do what). Children never
# see AI features (docs/design/ai.md, safety measure 8). A draft is seen, stopped and discarded only by who asked.
class FamilyStudies::DraftPolicy < ApplicationPolicy
  def create? = head_or_adult?
  def show? = create? && record.user_id == membership.user_id
  def destroy? = show?
end
