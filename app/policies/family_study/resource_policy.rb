class FamilyStudy::ResourcePolicy < ApplicationPolicy
  def show?   = member?
  def create? = head_or_adult?
end
