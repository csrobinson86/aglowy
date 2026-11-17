# Notes are their owner's alone, whatever their role, through any household they're active in (docs/design/notes.md:
# private, like everything in Mine).
class PersonalNotePolicy < ApplicationPolicy
  def index?   = member?
  def create?  = owner?
  def show?    = owner?
  def update?  = owner?
  def destroy? = owner?
  def tag?     = owner?
  def pin?     = owner?

  private

  def owner?
    member? && membership.user_id == record.user_id
  end
end
