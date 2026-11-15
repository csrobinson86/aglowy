# A new one-time password link for a child whose login is a username only, when the first one expired or the
# password is forgotten (docs/design/invitations.md, Child logins). Devise's reset email can't reach them.
class Members::PasswordLinksController < ApplicationController
  include HouseholdScoped

  def create
    authorize @member = Current.household.memberships.active.preloaded.find(params[:member_id]), :new_password_link?
    no_store # The page carries the password link.
  end
end
