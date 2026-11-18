# Every 15 minutes: today's brief for each unpaused plan that's due (docs/design/daily-brief.md, The morning job). A plan
# whose seven briefs before today went unseen is paused instead, and nil means go on to the next plan. Safe to run
# twice: the brief is one a day, found or made under the person's lock. Someone who is no longer a head or adult anywhere
# can't open a brief, so none is made for them; their plan and briefs are kept for when they're back.
class DailyBrief::PrepareJob < ApplicationJob
  def perform
    DailyBrief::Plan.unpaused.includes(:user, :pausing).find_each do |plan|
      DailyBrief.for(plan.user, pause_if_unseen: true) if plan.due? && plan.user.may_have_daily_brief?
    end
  end
end
