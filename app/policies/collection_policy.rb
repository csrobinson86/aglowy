# A person's own folders for Personal study and Notes, whatever their role (docs/design/personal-study.md, Collection).
class CollectionPolicy < ApplicationPolicy
  def create?  = member?
  def update?  = owner?
  def destroy? = owner?

  private

  def owner?
    member? && membership.user_id == record.user_id
  end
end
