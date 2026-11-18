# Parts are their owner's, whatever their role, through any household they're active in. Children add and prepare
# theirs like anyone else (docs/design/meeting-parts.md, Who can do what). Members of a household a part is shared with may
# read it, while its owner is still active there; only the owner shares it.
class MeetingPartPolicy < ApplicationPolicy
  def index?   = member?
  def create?  = member?
  def show?    = owner? || shared_here?
  def update?  = owner?
  def destroy? = owner?
  def share?   = owner?

  private

  def owner?
    member? && membership.user_id == record.user_id
  end

  def shared_here?
    member? && MeetingPart.shared_with(membership.household).exists?(record.id)
  end
end
