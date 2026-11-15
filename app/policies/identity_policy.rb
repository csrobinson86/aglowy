# Account settings' signing-in details (docs/design/invitations.md, Account settings). There's no household there,
# so the membership is nil: the person may edit only their own login, whatever their role anywhere.
class IdentityPolicy < ApplicationPolicy
  def update?
    Current.identity.present? && record == Current.identity
  end

  # A username-only login (a child's) changes only its password; an email is added elsewhere, if ever.
  def permitted_attributes
    record.email_login? ? %i[ email password current_password ] : %i[ password current_password ]
  end
end
