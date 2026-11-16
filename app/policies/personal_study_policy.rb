# Personal studies are their owner's alone, whatever their role, through any household they're active in
# (docs/design/personal-study.md, Who can do what). A head's read-only view of a child's studies comes with the study AI grant.
class PersonalStudyPolicy < ApplicationPolicy
  def index?   = member?
  def create?  = owner?
  def show?    = owner?
  def update?  = owner?
  def destroy? = owner?
  def tag?     = owner?

  private

  def owner?
    member? && membership.user_id == record.user_id
  end
end
