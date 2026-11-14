# The "Shared in <household>" tab: notes members have shared into this household, for every active
# member to read (docs/design/meeting-notes.md, Pages).
class SharedMeetingNotesController < ApplicationController
  include HouseholdScoped

  def index
    authorize MeetingNote
    @meeting_notes = MeetingNote.shared_with(Current.household).includes(:user).newest_first
  end
end
