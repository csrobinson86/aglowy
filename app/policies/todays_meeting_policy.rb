# Today's meeting is for everyone in the household: heads, adults and children each open their own note
# (docs/design/meeting-helper.md, Who can do what). The record is the household.
class TodaysMeetingPolicy < ApplicationPolicy
  def show?   = member_here?
  def create? = member_here?

  private
    def member_here?
      member? && membership.household_id == record.id
    end
end
