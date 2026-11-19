# The parent's listening game pages (docs/design/listening-game.md, Pages): for heads and adults of this household
# while the helper is on. A child, another household or the helper off gets a 404, not the usual redirect.
module ListeningGameScoped
  extend ActiveSupport::Concern

  included do
    include HouseholdScoped

    rescue_from(Pundit::NotAuthorizedError) { raise ActiveRecord::RecordNotFound }

    before_action { authorize Current.household, policy_class: ListeningGamePolicy }
  end
end
