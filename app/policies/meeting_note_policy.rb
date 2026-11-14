# Notes are personal: only their author reaches them, through any household they're active in.
# Sharing with a household comes later (docs/design/meeting-notes.md, Who can do what).
class MeetingNotePolicy < ApplicationPolicy
  def index?   = member?
  def create?  = member?
  def show?    = author?
  def update?  = author?
  def destroy? = author?

  private

  def author?
    member? && membership.user_id == record.user_id
  end
end
