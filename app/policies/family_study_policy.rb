class FamilyStudyPolicy < ApplicationPolicy
  def index?  = member?
  def show?   = member?
  def create? = head_or_adult?
  def update? = head_or_adult?
end
