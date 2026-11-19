# The parent's listening game pages (docs/design/listening-game.md, Pages): for heads and adults of this household
# while the helper is on. A child, another household or the helper off gets a 404, not the usual redirect.
module ListeningGameScoped
  extend ActiveSupport::Concern

  included do
    include HouseholdScoped

    rescue_from(Pundit::NotAuthorizedError) { raise ActiveRecord::RecordNotFound }

    before_action { authorize Current.household, policy_class: ListeningGamePolicy }
    # The answers are kept from the children: Back after a sign-out and a child's sign-in can't show them, as with the
    # daily brief. The views also keep the page out of Turbo's snapshot cache, which ignores no-store.
    before_action :no_store
  end
end
