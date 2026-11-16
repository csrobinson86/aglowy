# Turning on AI drafts (docs/design/ai.md, First use). No household in the URL, so the membership is nil and the
# record is the person accepting: authorize Current.user, policy_class: Ai::AcceptancePolicy. Only for themselves.
class Ai::AcceptancePolicy < ApplicationPolicy
  def create?
    Current.user.present? && record == Current.user
  end
end
