# One Get ready card, with Back and Next card through the meeting's cards (docs/design/meeting-prep.md, Pages and
# routes, A card; frames tablet-prep-card.png, tablet-prep-reading.png), and Change a card for a head or adult, in a
# dialog loaded into the parent's page's Turbo Frame (Change a card; frame phone-prep-change.png). A step with no card
# this week is a 404, and so is a save from a dialog opened in another week. A refused change shows the dialog again
# with each reason by its field; a saved one closes it and redraws the card.
class MeetingPreps::CardsController < ApplicationController
  include MeetingPrepScoped

  before_action :set_card
  before_action :ensure_this_week, only: :update

  def show
    @cards = cards_for(@card.meeting)
    @step = MeetingNote::HelperSteps.for(@card.meeting).fetch(@card.step)
    @meeting_note = Current.user.meeting_notes.includes(:answer).find_by(kind: @card.meeting, week_of: @week_of) if @step.answerable?
  end

  def edit
    @change = PrepWeek::Card::Change.new(@card)
  end

  def update
    @change = PrepWeek::Card::Change.new(@card, params.expect(prep_week_card_change: PrepWeek::Card::Change.attribute_names))

    if @change.save(by: Current.user)
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Card saved." }
        format.html { redirect_to household_meeting_preps_path, notice: "Card saved.", status: :see_other }
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_card
      @card = card_for(params[:meeting_prep_meeting], params[:id])
    end

    # The card is found by its step, so the dialog's form names its week: one left open past Monday can't save over the
    # new week's card.
    def ensure_this_week
      raise ActiveRecord::RecordNotFound, "Not this week's card" unless params[:week_of] == @week_of.iso8601
    end
end
