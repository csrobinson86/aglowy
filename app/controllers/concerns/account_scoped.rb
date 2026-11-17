# Account settings, outside any household (docs/design/invitations.md, Account settings): the focused layout and the
# signed-in person's own records, never an id from the URL. Only a person with no household sees it; everyone else
# has Settings (docs/design/settings.md, /account stays).
module AccountScoped
  extend ActiveSupport::Concern

  included do
    layout "focused"
    before_action :set_account
  end

  private
    def set_account
      @user = Current.user
      @identity = Current.identity
      @memberships = Current.user.memberships.active.by_household_name
    end
end
