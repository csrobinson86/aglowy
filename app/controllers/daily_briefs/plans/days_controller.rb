# Editing one weekday's row of the person's plan, in a dialog loaded into Your week's Turbo Frame (docs/design/daily-brief.md,
# Your plan). Found through Current.user's own plan by its wday, so a wday outside 0 to 6 is a 404. A refused save shows
# the dialog again with the reasons; a saved one closes it and redraws the week.
class DailyBriefs::Plans::DaysController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }
  before_action :set_day

  def edit
  end

  # A blank box takes its topic off: the topics sent replace the day's. The model refuses a key that isn't one of the
  # plan's own focus areas.
  def update
    if @day.revise(params.expect(daily_brief_day: [ :reading, :examples, topics: {} ]))
      close_dialog
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_day
      @plan = DailyBrief::Plan.find_by!(user: Current.user)
      @day = @plan.days.find_by!(wday: params[:wday])
    end

    # Empties the dialog's frame, which closes it, and redraws the week with the notice and focus on the day's Edit.
    # Without Turbo, back to the plan.
    def close_dialog
      notice = "#{@day.name} saved."

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
          @plan.reload
          render :saved
        end
        format.html { redirect_to household_daily_brief_plan_path, notice:, status: :see_other }
      end
    end
end
