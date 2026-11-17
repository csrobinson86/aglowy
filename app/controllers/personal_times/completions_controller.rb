# The done box on one day of a personal time (docs/design/calendar.md, My time's done box): created with the day as on,
# deleted with the day as its id. Answers with the card again, its box and its title's line changed.
class PersonalTimes::CompletionsController < ApplicationController
  include HouseholdScoped

  before_action :set_personal_time

  # A day that hasn't come yet, or one the time doesn't fall on.
  rescue_from(ActiveRecord::RecordInvalid) { head :unprocessable_content }

  def create
    @personal_time.complete(on: day(params[:on]))
    render_card
  end

  def destroy
    @personal_time.uncomplete(on: day(params[:id]))
    render_card
  end

  private
    # Through Current.user, so another person's time is a 404.
    def set_personal_time
      @personal_time = Current.user.personal_times.find(params[:personal_time_id])
      authorize @personal_time, :update?
    end

    def day(value)
      @day = Date.iso8601(value.to_s)
    rescue ArgumentError
      raise ActionController::BadRequest, "the day must be a date"
    end

    # The calendar's week is in the household's zone, where the person's day can fall on another date.
    def render_card
      @item = Household::Calendar::Item.from_time(@personal_time.occurrence_on(@day), household: Current.household)
      respond_to do |format|
        format.turbo_stream { render :card }
        format.html { redirect_to household_calendar_path(date: @item.starts_at.to_date.iso8601), status: :see_other }
      end
    end
end
