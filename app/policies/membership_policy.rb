class MembershipPolicy < ApplicationPolicy
  def index?  = member?
  def create? = head?
end
