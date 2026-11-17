# The person's own profile and appearance, in Settings and on /account (docs/design/settings.md, Traps). It never reads
# the membership, which is nil on /account: the person may edit only themselves, whatever their role anywhere.
class UserPolicy < ApplicationPolicy
  def update?
    Current.user.present? && record == Current.user
  end
end
