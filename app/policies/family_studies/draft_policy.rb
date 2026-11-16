# Heads and adults, like scheduling a study (docs/design/family-studies.md, AI helper: Who can do what). Children never
# see AI features (docs/design/ai.md, safety measure 8).
class FamilyStudies::DraftPolicy < ApplicationPolicy
  def create? = head_or_adult?
end
