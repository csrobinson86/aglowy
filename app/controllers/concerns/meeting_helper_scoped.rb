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
  end

  private

  def authorize_meeting_helper
    authorize Current.household, :show?, policy_class: MeetingHelperPolicy
  end

  def set_meeting_note
    @meeting_note = Current.user.meeting_notes.find(params[:meeting_note_id])
  end
end
