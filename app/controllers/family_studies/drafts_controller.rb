# Family study drafts from the AI panel (docs/design/family-studies.md, AI helper: Routes). Every answer is the panel:
# Drafting once a draft starts, the draft's current state on show, and Describe, with its text, after a Stop or Discard.
class FamilyStudies::DraftsController < ApplicationController
  include HouseholdScoped

  # Only the person's own drafts in this household, so anyone else's is a 404.
  before_action :set_draft, only: %i[ show destroy ]
  before_action { authorize @draft || FamilyStudy::Draft, policy_class: FamilyStudies::DraftPolicy }
  # The panel hides the prompt until then, but the server doesn't trust the UI (docs/design/ai.md, First use).
  before_action { head :forbidden unless Current.user.accepted_ai_terms? }

  def create
    draft = FamilyStudy::Draft.start(household: Current.household, user: Current.user, **draft_params)

    render turbo_stream: turbo_stream.replace(:ai_panel, panel(draft)), status: draft.persisted? ? :ok : :unprocessable_content
  end

  # The panel alone, for its Turbo Frame. As a Turbo Stream it's asked for once the panel listens on the draft's
  # stream: a result that came in before then was broadcast to nobody, so it comes from here (nothing while drafting).
  def show
    respond_to do |format|
      format.html { render panel(@draft), layout: false }
      format.turbo_stream { @draft.drafting? ? head(:no_content) : render(turbo_stream: turbo_stream.replace(:ai_panel, panel(@draft))) }
    end
  end

  def destroy
    @draft.stop_or_discard

    # An unsaved copy: Describe, with the draft's text and options kept.
    render turbo_stream: turbo_stream.replace(:ai_panel, panel(@draft.dup))
  end

  private
    def set_draft
      @draft = Current.user.family_study_drafts.where(household: Current.household).find(params[:id])
    end

    def panel(draft)
      FamilyStudies::AiPanelComponent.new(household: Current.household, user: Current.user, draft:, open: true)
    end

    # Every keyword start takes, even when a crafted request leaves one out. young_children is never nil (not null).
    def draft_params
      params.expect(family_study_draft: %i[ prompt length_minutes young_children ])
        .then { { prompt: it[:prompt], length_minutes: it[:length_minutes], young_children: ActiveModel::Type::Boolean.new.cast(it[:young_children]) == true } }
    end
end
