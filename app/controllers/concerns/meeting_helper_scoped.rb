# The meeting helper's own pages (docs/design/meeting-helper.md, Who can do what): only for a child of this household
# while the household has the helper on, and only on their own note (Trap 1). Anyone else gets a 404, not the usual
# redirect, like a step the note's kind doesn't have (Trap 2).
module MeetingHelperScoped
  extend ActiveSupport::Concern

  included do
    include HouseholdScoped

    layout "meeting_helper"

    rescue_from(Pundit::NotAuthorizedError) { raise ActiveRecord::RecordNotFound }

    before_action :authorize_meeting_helper
    before_action :set_meeting_note

    helper_method :from_prep?, :back_to_step_path
  end

  private

  def authorize_meeting_helper
    authorize Current.household, :show?, policy_class: MeetingHelperPolicy
  end

  def set_meeting_note
    @meeting_note = Current.user.meeting_notes.find(params[:meeting_note_id])
  end

  # She came from a Get ready card (docs/design/meeting-prep.md, Back to her card). from is checked against this one
  # value and is never a URL (Trap 6).
  def from_prep?
    params[:from] == "prep"
  end

  # Where saving, Back and All done go: the Get ready card for the step when she came from it, the step otherwise.
  def back_to_step_path(step)
    if from_prep?
      household_meeting_prep_card_path(meeting_prep_meeting: @meeting_note.kind, id: step.key)
    else
      household_meeting_note_step_path(meeting_note_id: @meeting_note, id: step.key)
    end
  end
end
