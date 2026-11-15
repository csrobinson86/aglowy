class MembershipPolicy < ApplicationPolicy
  def index?  = member?
  def create? = head_or_adult?
end
