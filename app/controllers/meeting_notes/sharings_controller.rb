# Sharing a note with the household in the URL, and stopping. A person in two households shares into
# this one only (docs/design/meeting-notes.md, Pages, "Share / stop sharing").
class MeetingNotes::SharingsController < ApplicationController
  include HouseholdScoped

  before_action :set_meeting_note

  def create
    @meeting_note.share_with(Current.household)
    redirect_to meeting_note_path, notice: "Shared with #{Current.household.name}."
  end

  def destroy
    @meeting_note.stop_sharing_with(Current.household)
    redirect_to meeting_note_path, notice: "Stopped sharing with #{Current.household.name}."
  end

  private

  # Through Current.user, so someone else's note is a 404.
  def set_meeting_note
    @meeting_note = Current.user.meeting_notes.find(params[:meeting_note_id])
    authorize @meeting_note, :share?
  end

  def meeting_note_path
    household_meeting_note_path(id: @meeting_note)
  end
end
