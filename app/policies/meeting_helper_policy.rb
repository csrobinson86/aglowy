# The meeting helper's pages are for a child of this household while the household has the helper on
# (docs/design/meeting-helper.md, Who can do what; Trap 6). The record is the household. Its controllers
# answer 404, not the usual redirect, when it fails.
class MeetingHelperPolicy < ApplicationPolicy
  def show?
    member? && membership.child? && membership.household_id == record.id && record.meeting_helper?
  end
end
