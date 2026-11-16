# A head's say-so for a child to ask the AI in their personal study, as a record: it exists while it's on. Only made
# through Membership#grant_study_ai, for an active child with a login; Membership#revoke_study_ai deletes it
# (docs/design/personal-study.md, Children). Heads who can see it can read that child's personal studies.
class Membership::StudyAiGrant < ApplicationRecord
  belongs_to :membership
  belongs_to :granted_by, class_name: "User"

  # The database can't look across tables at the seat's role or the person's login.
  validate :child_with_login

  private

  def child_with_login
    if !membership.active? || !membership.child?
      errors.add(:membership, "is only for children")
    elsif membership.user.identity.nil?
      errors.add(:membership, "needs a login first")
    end
  end
end
