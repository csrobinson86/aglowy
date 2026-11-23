# Heads and adults add, edit and remove items, and tick "we have it" (update?); children only look
# (docs/design/go-bags.md, Who can do what).
class GoBag::ItemPolicy < ApplicationPolicy
  def create?  = head_or_adult?
  def update?  = head_or_adult?
  def destroy? = head_or_adult?
end
