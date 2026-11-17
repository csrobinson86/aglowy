# Bookmarks are their owner's alone, whatever their role, through any household they're active in
# (docs/design/bookmarks.md: private, like everything in Mine).
class BookmarkPolicy < ApplicationPolicy
  def index?   = member?
  def create?  = owner?
  def update?  = owner?
  def destroy? = owner?
  def tag?     = owner?

  private

  def owner?
    member? && membership.user_id == record.user_id
  end
end
