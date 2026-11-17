# Anyone in the household, children too, adds, edits and deletes their own times and marks them done
# (docs/design/calendar.md, Who can do what). Times are found through Current.user, which is what keeps everyone else's
# out: another person's time is a 404, even a shared one (Trap 3).
class PersonalTimePolicy < ApplicationPolicy
  def create?  = member?
  def update?  = member?
  def destroy? = member?
end
