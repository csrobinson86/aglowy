# One step of the meeting helper: the part's picture and prompt, with Back and Next
# (docs/design/meeting-helper.md, Pages, A step). Only for a child while the household has the helper on;
# anyone else gets a 404, like someone else's note (Trap 1) or a step the note's kind doesn't have (Trap 2).
class MeetingNotes::StepsController < ApplicationController
  include HouseholdScoped

  layout "meeting_helper"

  rescue_from(Pundit::NotAuthorizedError) { raise ActiveRecord::RecordNotFound }

  before_action { authorize Current.household, :show?, policy_class: MeetingHelperPolicy }

  def show
    @meeting_note = Current.user.meeting_notes.find(params[:meeting_note_id])
    @steps = @meeting_note.helper_steps
    @step = @steps.fetch(params[:id])
  end
end
