# The shared list on the Meeting notes tab: notes members have shared into this household, for every active member to
# read (docs/design/meeting-notes.md, Pages). Filtered by a meeting, it drops my This week cards, as my own list does.
class SharedMeetingNotesController < ApplicationController
  include HouseholdScoped
  include KindFiltered

  def index
    authorize MeetingNote
    shared = MeetingNote.shared_with(Current.household)
    @kind_counts = shared.group(:kind).count
    @shared_count = @kind_counts.values.sum
    @this_week = Current.user.meeting_notes_for_week(Current.membership.this_week) unless @kind
    # A week at a time, as my own list, and flat when filtered by a meeting (docs/design/notes.md, Earlier, a week at a time).
    if @kind
      @meeting_notes = of_kind(shared).includes(:user).newest_first
    else
      @weeks = shared.includes(:user).in_week_order.group_by(&:week_of)
    end
  end
end
