# Get my comment ready and Draw it! on a Get ready card (docs/design/meeting-prep.md, Pages and routes): starts her note
# for the meeting, or finds the one she has, then opens her answer on the meeting's answerable step (to=answer) or the
# Bible Reading drawing (to=drawing), each with from=prep so saving brings her back to the card. Any other to or
# meeting, or a step with no card this week, is a 404.
class MeetingPreps::NotesController < ApplicationController
  include MeetingPrepScoped

  def create
    meeting = params[:meeting_prep_meeting].presence_in(Household::MEETING_KINDS) or raise ActiveRecord::RecordNotFound
    card = card_for(meeting, step_key(meeting))
    meeting_note = Current.user.start_meeting_note(kind: meeting, week_of: @week_of)

    if params[:to] == "answer"
      redirect_to edit_household_meeting_note_step_answer_path(meeting_note_id: meeting_note, step_id: card.step, from: "prep")
    else
      redirect_to edit_household_meeting_note_step_drawing_path(meeting_note_id: meeting_note, step_id: card.step, from: "prep")
    end
  end

  private

  def step_key(meeting)
    case params[:to]
    when "answer" then MeetingNote::HelperSteps.for(meeting).answerable.key
    when "drawing" then "bible_reading"
    else raise ActiveRecord::RecordNotFound, "No note page #{params[:to].inspect}"
    end
  end
end
