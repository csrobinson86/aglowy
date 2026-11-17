# Everyone in the household sees its calendar, children too (docs/design/calendar.md, Who can do what).
# The record is the household.
class CalendarPolicy < ApplicationPolicy
  def show? = member? && membership.household_id == record.id
end
