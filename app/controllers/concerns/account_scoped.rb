# Account settings, outside any household (docs/design/invitations.md, Account settings): the focused layout, the
# signed-in person's own records (never an id from the URL), and the way back to the household they came from.
module AccountScoped
  extend ActiveSupport::Concern

  included do
    layout "focused"
    before_action :set_account
    helper_method :return_to_params
  end

  private
    # return_to counts only if it's one of the person's active households, so it can never send them anywhere else.
    def set_account
      @user = Current.user
      @identity = Current.identity
      @return_household = Current.user.active_household(params[:return_to])
      @memberships = Current.user.memberships.active.by_household_name
    end

    def return_to_params
      { return_to: @return_household&.id }
    end
end
