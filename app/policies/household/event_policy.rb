# Heads and adults add, edit and delete household events; children only see them (docs/design/calendar.md, Who can do
# what). Hiding the button isn't the check: this is (Trap 4). Events are found through Current.household.
class Household::EventPolicy < ApplicationPolicy
  def create?  = head_or_adult?
  def update?  = head_or_adult?
  def destroy? = head_or_adult?
end
