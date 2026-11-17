class MembershipPolicy < ApplicationPolicy
  def index?  = member?
  def create? = head_or_adult?

  # A child's login: heads and adults give one to a child without a login, and make a new password link for a
  # child whose login is a username only (docs/design/invitations.md, Child logins). Never for adults or heads.
  def give_login?        = manage_login? && record.user.identity.nil?
  def new_password_link? = manage_login? && record.user.identity.present? && record.user.identity.email.nil?

  # Changing a role and removing a member, from household settings: heads of the member's household only
  # (docs/design/invitations.md, Who can do what). The last head is refused by Membership, under the lock.
  def update?  = head? && record.household_id == membership.household_id
  def destroy? = update?

  # Leaving a household from Settings or /account, without reading the membership (nil on /account): only the person's
  # own seat, and never a child's (a head or adult removes them). The last head is refused by Membership#deactivate, under the lock.
  def leave?
    Current.user.present? && record.user == Current.user && !record.child?
  end

  private
    def manage_login?
      head_or_adult? && record.child? && record.household_id == membership.household_id
    end
end
