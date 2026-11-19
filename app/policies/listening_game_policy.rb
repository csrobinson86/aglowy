# The parent's listening game page and changing a round: heads and adults of this household while it has the meeting
# helper on (docs/design/listening-game.md, Pages, Who sees the parent's page). The record is the household. Its
# controllers answer 404, not the usual redirect, when it fails.
class ListeningGamePolicy < ApplicationPolicy
  def show?
    head_or_adult? && membership.household_id == record.id && record.meeting_helper?
  end

  def update? = show?
end
