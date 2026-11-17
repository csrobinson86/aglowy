class MembersController < ApplicationController
  include HouseholdScoped

  before_action(except: :destroy) { authorize Membership }

  def index
    @memberships = Current.household.memberships.active.preloaded.includes(:study_ai_grant).by_role
    # Invitations show other people's addresses, so children don't get them.
    @invitations = Current.household.invitations.preloaded.newest_first if policy(Invitation).create?
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

  # Removing someone, from household settings, works like them leaving (Membership#deactivate). A head may remove
  # themselves unless they're the last head; the refusal comes back on their row.
  def destroy
    # Through Current.household, so another household's member is a 404.
    authorize @member = Current.household.memberships.active.preloaded.find(params[:id])

    if !@member.deactivate
      render turbo_stream: turbo_stream.replace(@member, partial: "households/settings/member", locals: { member: @member, focused: true }),
             status: :unprocessable_content
    elsif @member == Current.membership
      redirect_to households_path(household_id: nil), notice: "You left the #{Current.household.name}.", status: :see_other
    else
      redirect_to edit_household_settings_household_path, notice: "#{@member.user.name} was removed from the household.", status: :see_other
    end
  end

  private

  # Only a name and a non-head role; the household comes from the URL, never the params.
  def member_params
    @member_params ||= params.expect(member: %i[ name role ]).tap do |member|
      raise ActionController::BadRequest, "role must be adult or child" unless member[:role].in?(Household::MEMBER_ROLES)
    end
  end
end
