# The person's daily brief: the newest one on or before today, and "Prepare today's brief" (docs/design/daily-brief.md,
# The brief and The morning job). Found through Current.user in any household they're active in; someone with no plan
# starts one first.
class DailyBriefsController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }
  before_action :no_store # It's personal: Back, which skips revalidating, can't show it to the next person to sign in.
  before_action :set_plan

  # Opening it counts as seeing it, the one fact the pause rule reads (Trap 5). Paused, the page says why instead.
  # ?part=evening is This evening, for a brief whose writing has evening questions; otherwise it's the morning.
  def show
    return render :paused if @plan.paused?

    @today = Current.user.today
    @brief = Current.user.daily_briefs.shown_on(@today)
    @brief&.mark_seen
    @evening = params[:part] == "evening" && @brief&.evening_questions.present?
  end

  # Today's, whatever due? says. DailyBrief.for makes none for a paused plan, and show then says it's paused.
  def create
    DailyBrief.for(Current.user)
    redirect_to household_daily_brief_path
  end

  private
    def set_plan
      @plan = DailyBrief::Plan.find_by(user: Current.user) or redirect_to new_household_daily_brief_plan_path
    end
end
