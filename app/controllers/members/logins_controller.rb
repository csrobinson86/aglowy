# Giving a child a username login, then showing the one-time password link (docs/design/invitations.md, Child logins).
class Members::LoginsController < ApplicationController
  include HouseholdScoped

  before_action :set_member

  def new
    @identity = Identity.new
  end

  def create
    @identity = @member.user.give_login(username: params.expect(identity: [ :username ])[:username])

    if @identity.persisted?
      no_store # The page carries the password link.
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    # Through Current.household, so another household's member is a 404.
    def set_member
      authorize @member = Current.household.memberships.active.preloaded.find(params[:member_id]), :give_login?
    end
end
