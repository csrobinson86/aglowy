# Notes are personal: only their author reaches them, through any household they're active in, and only
# the author shares them into that household. Members of a household a note is shared with may read it,
# while its author is still active there (docs/design/meeting-notes.md, Who can do what).
class MeetingNotePolicy < ApplicationPolicy
  def index?   = member?
  def create?  = member?
  def show?    = author? || shared_here?
  def update?  = author?
  def destroy? = author?
  def share?   = author?
  def tag?     = author?

  private

  def author?
    member? && membership.user_id == record.user_id
  end

  def shared_here?
    member? && MeetingNote.shared_with(membership.household).exists?(record.id)
  end
end
