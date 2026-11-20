# Get ready (docs/design/meeting-prep.md, Pages and routes; frame tablet-prep-week.png): a tile for each of this week's
# meetings, and a meeting, which opens at its first card.
class MeetingPrepsController < ApplicationController
  include MeetingPrepScoped

  def index
    @meetings = Current.household.this_weeks_meetings
  end

  # A meeting with no cards goes back to Get ready, which says they aren't ready yet.
  def show
    card = cards_for(params[:meeting]).first

    redirect_to card ? household_meeting_prep_card_path(meeting_prep_meeting: card.meeting, id: card.step) : household_meeting_preps_path
  end
end
