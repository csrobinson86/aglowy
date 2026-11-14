class MembershipPolicy < ApplicationPolicy
  def create? = head?
end
