# Starting a family study draft from the AI panel (docs/design/family-studies.md, AI helper: Routes). Every answer
# replaces the panel: Drafting once it starts, Limit reached, or Describe with the errors.
class FamilyStudies::DraftsController < ApplicationController
  include HouseholdScoped

  before_action { authorize FamilyStudy::Draft, policy_class: FamilyStudies::DraftPolicy }
  # The panel hides the prompt until then, but the server doesn't trust the UI (docs/design/ai.md, First use).
  before_action { head :forbidden unless Current.user.accepted_ai_terms? }

  def create
    draft = FamilyStudy::Draft.start(household: Current.household, user: Current.user, **draft_params)

    render turbo_stream: turbo_stream.replace(:ai_panel, FamilyStudies::AiPanelComponent.new(household: Current.household, user: Current.user, draft:, open: true)),
      status: draft.persisted? ? :ok : :unprocessable_content
  end

  private
    # Every keyword start takes, even when a crafted request leaves one out. young_children is never nil (not null).
    def draft_params
      params.expect(family_study_draft: %i[ prompt length_minutes young_children ])
        .then { { prompt: it[:prompt], length_minutes: it[:length_minutes], young_children: ActiveModel::Type::Boolean.new.cast(it[:young_children]) == true } }
    end
end
