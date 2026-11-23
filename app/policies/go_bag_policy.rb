# Every member sees the household's bags; heads and adults make, change and delete them, and see To buy
# (docs/design/go-bags.md, Who can do what). Bags are found through Current.household, so another household's is a 404.
class GoBagPolicy < ApplicationPolicy
  def index?         = member?
  def show?          = member?
  def create?        = head_or_adult?
  def update?        = head_or_adult?
  def destroy?       = head_or_adult?
  def shopping_list? = head_or_adult?
end
