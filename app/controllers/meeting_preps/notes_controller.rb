# Get my comment ready and Draw it! on a Get ready card (docs/design/meeting-prep.md, Pages and routes): starts her note
# for the meeting, or finds the one she has, then opens her answer on the meeting's answerable step (to=answer) or the
# Bible Reading drawing (to=drawing), each with from=prep so saving brings her back to the card. Any other to or
# meeting, or a step with no card this week, is a 404.
class MeetingPreps::NotesController < ApplicationController
  include MeetingPrepScoped

  # For each to, the step it opens and the page.
  PAGES = {
    "answer" => [ ->(meeting) { MeetingNote::HelperSteps.for(meeting).answerable.key }, :edit_household_meeting_note_step_answer_path ],
    "drawing" => [ ->(_meeting) { "bible_reading" }, :edit_household_meeting_note_step_drawing_path ]
  }.freeze

  def create
    meeting = params[:meeting_prep_meeting].presence_in(Household::MEETING_KINDS) or raise ActiveRecord::RecordNotFound
    step_key, page = PAGES.fetch(params[:to]) { raise ActiveRecord::RecordNotFound, "No note page #{params[:to].inspect}" }
    card = card_for(meeting, step_key.call(meeting))
    meeting_note = Current.user.start_meeting_note(kind: meeting, week_of: @week_of)

    redirect_to public_send(page, meeting_note_id: meeting_note, step_id: card.step, from: "prep")
  end
end
