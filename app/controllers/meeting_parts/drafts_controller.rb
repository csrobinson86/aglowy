# Prepare with AI on a part's page (docs/design/meeting-parts.md, Pages and routes). Every answer is the panel: Drafting
# once a draft starts, the draft's current state on show, and Start, with the request kept, after a Stop or Discard.
class MeetingParts::DraftsController < ApplicationController
  include HouseholdScoped

  # The person's own part, as a head or adult, on every action, so a child never reaches the AI (Trap 1) and anyone
  # else's part, shared here or not, is a 404.
  before_action :set_meeting_part
  before_action :set_draft, only: %i[ show destroy ]
  # The panel hides the request box until then, but the server doesn't trust the UI (docs/design/ai.md, First use).
  before_action { head :forbidden unless Current.user.accepted_ai_terms? }

  # An outline or sample wording; or, with revises_id, a change or sample wording built on one of the person's own drafts
  # of this part, so anyone else's is a 404.
  def create
    attributes = params.expect(meeting_part_draft: [ :kind, :request, :revises_id ])
    revises = @meeting_part.drafts.where(user: Current.user).find(attributes[:revises_id]) if attributes[:revises_id].present?
    draft = @meeting_part.draft(kind: attributes.fetch(:kind, "outline"), request: attributes[:request], revises: revises, by: Current.user)

    render turbo_stream: turbo_stream.replace(:ai_panel, panel(draft)), status: draft.persisted? ? :ok : :unprocessable_content
  end

  # The panel alone, for a reload. As a Turbo Stream it's asked for once the panel listens on the draft's stream, and
  # again when the job says it's done: nothing while drafting.
  def show
    respond_to do |format|
      format.html { render panel(@draft), layout: false }
      format.turbo_stream { @draft.drafting? ? head(:no_content) : render(turbo_stream: turbo_stream.replace(:ai_panel, panel(@draft))) }
    end
  end

  # Never deletes the draft, so a stopped request keeps its use and still counts. Start keeps what was typed for it, but
  # not a change, which only meant something under the draft it changed.
  def destroy
    @draft.stop_or_discard

    render turbo_stream: turbo_stream.replace(:ai_panel, panel(@meeting_part.drafts.new(kind: @draft.kind, request: (@draft.request unless @draft.change?))))
  end

  private
    def set_meeting_part
      @meeting_part = Current.user.meeting_parts.find(params[:meeting_part_id])
      authorize @meeting_part, :draft?
    end

    def set_draft
      @draft = @meeting_part.drafts.where(user: Current.user).find(params[:id])
    end

    def panel(draft)
      MeetingParts::AiPanelComponent.new(household: Current.household, meeting_part: @meeting_part, user: Current.user, draft: draft, open: true)
    end
end
