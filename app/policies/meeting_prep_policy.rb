# Get ready's pages for a child of this household while it has both the meeting helper and Get ready on
# (docs/design/meeting-prep.md, Who can do what). Heads and adults get their own page later, so for now Get ready is
# hers alone. The record is the household. Its controllers answer 404, not the usual redirect, when it fails.
class MeetingPrepPolicy < ApplicationPolicy
  def index?
    member? && membership.child? && membership.household_id == record.id && record.meeting_prep?
  end

  def show? = index?

  # Starting her note from a card, for her comment or Draw it!.
  def create? = index?
end
