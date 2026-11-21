# One Get ready card, with Back and Next card through the meeting's cards (docs/design/meeting-prep.md, Pages and
# routes, A card; frames tablet-prep-card.png, tablet-prep-reading.png). A step with no card is a 404.
class MeetingPreps::CardsController < ApplicationController
  include MeetingPrepScoped

  def show
    @cards = cards_for(params[:meeting_prep_meeting])
    @card = card_for(params[:meeting_prep_meeting], params[:id])
    @step = MeetingNote::HelperSteps.for(@card.meeting).fetch(@card.step)
    @meeting_note = Current.user.meeting_notes.includes(:answer).find_by(kind: @card.meeting, week_of: @week_of) if @step.answerable?
  end
end
