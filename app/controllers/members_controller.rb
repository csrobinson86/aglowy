class MembersController < ApplicationController
  include HouseholdScoped

  before_action { authorize Membership }

  def index
    @memberships = Current.household.memberships.active.preloaded.by_role
  end

  def new
    @member = User.new
  end

  def create
    membership = Current.household.add_member(name: member_params[:name], role: member_params[:role])
    redirect_to household_members_path, notice: "#{membership.user.name} was added to the household."
  rescue ActiveRecord::RecordInvalid => invalid
    @member, @role = invalid.record, member_params[:role]
    render :new, status: :unprocessable_content
  end

  private

  # Only a name and a non-head role; the household comes from the URL, never the params.
  def member_params
    @member_params ||= params.expect(member: %i[ name role ]).tap do |member|
      raise ActionController::BadRequest, "role must be adult or child" unless member[:role].in?(Household::MEMBER_ROLES)
    end
  end
end
