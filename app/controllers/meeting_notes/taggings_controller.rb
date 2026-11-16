# The owner's tags on their meeting note (docs/design/tags.md, The tag editor).
class MeetingNotes::TaggingsController < ApplicationController
  include HouseholdScoped
  include TaggableScoped

  private

  # Through Current.user, so someone else's note, even shared with the household, is a 404.
  def set_taggable
    @taggable = Current.user.meeting_notes.find(params[:meeting_note_id])
    authorize @taggable, :tag?
  end
end
