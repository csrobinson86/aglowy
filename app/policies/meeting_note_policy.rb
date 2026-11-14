# Notes are personal: only their author reaches them, through any household they're active in, and only
# the author shares them into that household. Reading a shared note comes next (docs/design/meeting-notes.md,
# Who can do what).
class MeetingNotePolicy < ApplicationPolicy
  def index?   = member?
  def create?  = member?
  def show?    = author?
  def update?  = author?
  def destroy? = author?
  def share?   = author?

  private

  def author?
    member? && membership.user_id == record.user_id
  end
end
