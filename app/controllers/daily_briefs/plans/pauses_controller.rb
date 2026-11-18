# Pausing the person's daily brief, and starting it again (docs/design/daily-brief.md, DailyBrief::Pause and Your plan).
# Found through Current.user's own plan. Pausing a paused plan, or starting one that isn't paused, changes nothing.
class DailyBriefs::Plans::PausesController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }
  before_action :set_plan

  # The plan's Banner says it's paused, so no notice as well.
  def create
    @plan.pause(reason: "chosen")
    redirect_to household_daily_brief_plan_path
  end

  def destroy
    @plan.resume
    redirect_to household_daily_brief_plan_path, notice: "Your daily brief is on again. Your next brief is ready tomorrow morning.",
                                                 status: :see_other
  end

  private
    def set_plan
      @plan = DailyBrief::Plan.find_by!(user: Current.user)
    end
end
