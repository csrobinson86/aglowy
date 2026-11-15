# Account settings' profile (docs/design/invitations.md, Account settings). There's no household there, so the
# membership is nil: the person may edit only themselves, whatever their role anywhere.
class UserPolicy < ApplicationPolicy
  def update?
    Current.user.present? && record == Current.user
  end
end
