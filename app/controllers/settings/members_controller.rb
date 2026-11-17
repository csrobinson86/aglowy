# Settings → Members and roles, heads only (docs/design/settings.md). Each row's role saves through
# Members::RolesController and Remove through MembersController#destroy, which comes back here.
class Settings::MembersController < ApplicationController
  include HouseholdScoped

  def index
    authorize Current.household, :update?
    @memberships = Current.household.memberships.active.preloaded.by_role
  end
end
