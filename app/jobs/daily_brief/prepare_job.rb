# Every 15 minutes: today's brief for each unpaused plan that's due (docs/design/daily-brief.md, The morning job). A plan
# whose seven briefs before today went unseen is paused instead, and nil means go on to the next plan. Safe to run
# twice: the brief is one a day, found or made under the person's lock.
class DailyBrief::PrepareJob < ApplicationJob
  def perform
    DailyBrief::Plan.unpaused.includes(:user, :pausing).find_each do |plan|
      DailyBrief.for(plan.user, pause_if_unseen: true) if plan.due?
    end
  end
end
