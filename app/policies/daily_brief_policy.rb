# The daily brief is the person's own, for heads and adults only: every action is User#may_have_daily_brief?, from any
# household they're active in. Children are refused everything (docs/design/daily-brief.md, Who can do what; Trap 10).
class DailyBriefPolicy < ApplicationPolicy
  def index?   = may_have_daily_brief?
  def show?    = may_have_daily_brief?
  def create?  = may_have_daily_brief?
  def update?  = may_have_daily_brief?
  def destroy? = may_have_daily_brief?

  private
    def may_have_daily_brief?
      member? && membership.user.may_have_daily_brief?
    end
end
