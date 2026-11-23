# Heads and adults list, add, rename and delete the household's categories in Settings → Go bags
# (docs/design/go-bags.md, Who can do what).
class GoBag::CategoryPolicy < ApplicationPolicy
  def index?   = head_or_adult?
  def create?  = head_or_adult?
  def update?  = head_or_adult?
  def destroy? = head_or_adult?
end
