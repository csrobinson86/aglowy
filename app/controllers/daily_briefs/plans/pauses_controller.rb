# Pausing the person's daily brief, and starting it again (docs/design/daily-brief.md, DailyBrief::Pause and Your plan).
# Found through Current.user's own plan. Pausing a paused plan, or starting one that isn't paused, changes nothing.
class DailyBriefs::Plans::PausesController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }
  before_action :set_plan

  # The plan's Banner says it's paused, so no notice as well.
  def create
    @plan.pause(reason: "chosen")
    redraw
  end

  # The notice only when it did start again: from an older tab, a plan already running keeps its started_at.
  def destroy
    redraw notice: ("Your daily brief is on again. Your next brief is ready tomorrow morning." if @plan.resume)
  end

  private
    def set_plan
      @plan = DailyBrief::Plan.find_by!(user: Current.user)
    end

    # Redraws the Banner and the Pause button in place. Without Turbo, back to the plan.
    def redraw(notice: nil)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
          render :saved
        end
        format.html { redirect_to household_daily_brief_plan_path, notice:, status: :see_other }
      end
    end
end
