# Heads and adults invite; only heads invite heads. Resending and cancelling: heads, or the adult who sent it
# (docs/design/invitations.md, "Who can do what").
class InvitationPolicy < ApplicationPolicy
  def create? = head_or_adult?

  def create_as?(role)
    case role.to_s
    when "adult" then create?
    when "head"  then head?
    else false
    end
  end

  # A built invitation: hiding the Head option isn't authorization, so the role it carries is checked here.
  def create_with_role? = create_as?(record.role)

  def update?  = in_household? && (head? || (head_or_adult? && record.invited_by_id == membership.user_id))
  def destroy? = update?

  private
    def in_household?
      member? && record.household_id == membership.household_id
    end
end
