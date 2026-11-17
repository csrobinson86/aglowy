# A member's role, from Settings → Members and roles, heads only (docs/design/settings.md). The select saves as soon as
# it changes, and the row comes back in place, with the reason when refused.
class Members::RolesController < ApplicationController
  include HouseholdScoped

  def update
    # Through Current.household, so another household's member is a 404.
    authorize @member = Current.household.memberships.active.preloaded.find(params[:member_id])

    if !@member.change_role(params.expect(membership: [ :role ])[:role])
      @member.restore_attributes # An unknown role shows the role they still have.
      render status: :unprocessable_content
    elsif @member == Current.membership && !@member.head?
      # No longer a head, so Members and roles would turn them away.
      redirect_to household_root_path, notice: "You're now #{role_with_article} in #{Current.household.name}.", status: :see_other
    else
      flash.now[:notice] = "#{@member.user.name} is now #{role_with_article}."
    end
  end

  private
    def role_with_article
      "#{@member.adult? ? "an" : "a"} #{@member.role}"
    end
end
