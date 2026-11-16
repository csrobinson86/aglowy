# Turning on AI drafts (docs/design/ai.md, First use). There's no household here, so the membership is nil: the
# person accepts only for themselves, and the acceptance follows them into every household.
class AiAcceptancesController < ApplicationController
  # A path in one of the person's own households, and nothing else: no host, no scheme, no stray characters.
  RETURN_PATH = %r{\A/(?<household_id>\h{8}-\h{4}-\h{4}-\h{4}-\h{12})(?:/[\w/-]*)?(?:\?[\w=&%-]*)?\z}

  before_action { authorize Current.user, :update? }

  def create
    acceptance = Current.user.accept_ai_terms(understood: params.dig(:ai_acceptance, :understood))

    if acceptance.persisted?
      redirect_to return_path, status: :see_other
    else
      render turbo_stream: turbo_stream.replace(:ai_terms, partial: "ai_acceptances/form", locals: { acceptance:, return_to: return_path }),
        status: :unprocessable_content
    end
  end

  private
    # Back to the form when return_to is a path in one of the person's active households, else the households page.
    def return_path
      match = RETURN_PATH.match(params[:return_to].to_s)
      match && Current.user.active_household(match[:household_id]) ? match.to_s : households_path
    end
end
