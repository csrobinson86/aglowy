# Parts are their owner's, whatever their role, through any household they're active in. Children add and prepare
# theirs like anyone else (docs/design/meeting-parts.md, Who can do what). Sharing comes later.
class MeetingPartPolicy < ApplicationPolicy
  def index?   = member?
  def create?  = member?
  def show?    = owner?
  def update?  = owner?
  def destroy? = owner?

  private

  def owner?
    member? && membership.user_id == record.user_id
  end
end
