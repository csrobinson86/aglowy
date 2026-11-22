# Pinning a note to the top of Notes and onto Home, and unpinning it (docs/design/notes.md, PersonalNote::Pin).
# Answers with a Turbo Stream: the note page's toggle swaps in place, keeping what hasn't been saved. The list, which
# alone knows its filters, refreshes, and so does the read view after its phone "…" pins, so the menu names the new
# state. Without Turbo, back to where the person was.
class PersonalNotes::PinsController < ApplicationController
  include HouseholdScoped

  before_action :set_personal_note

  def create
    @personal_note.pin_to_top
    respond_with_pin
  end

  def destroy
    @personal_note.unpin
    respond_with_pin
  end

  private

  # Through Current.user, so someone else's note is a 404.
  def set_personal_note
    @personal_note = Current.user.personal_notes.find(params[:personal_note_id])
    authorize @personal_note, :pin?
  end

  def respond_with_pin
    respond_to do |format|
      format.turbo_stream do
        @refresh = params[:from].in?(%w[ list menu ])
        render :pin
      end
      format.html { redirect_back_or_to household_personal_note_path(id: @personal_note), status: :see_other }
    end
  end
end
