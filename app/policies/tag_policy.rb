# A person's own tags, the same in every household they're active in. Nobody else reaches them, whatever their role
# (docs/design/tags.md, Privacy).
class TagPolicy < ApplicationPolicy
  def index?   = member?
  def show?    = owner?
  def update?  = owner?
  def destroy? = owner?

  private

  def owner?
    member? && membership.user_id == record.user_id
  end
end
