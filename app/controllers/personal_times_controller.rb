# Adding, editing and deleting the signed-in person's own times, in a dialog loaded into the calendar's Turbo Frame
# (docs/design/calendar.md, The "my time" dialog). Everything goes through Current.user, so another person's time is a
# 404. A refused save shows the dialog again with the reasons; a saved one closes it and refreshes the calendar.
class PersonalTimesController < ApplicationController
  include HouseholdScoped

  before_action :set_personal_time, only: %i[ edit update destroy ]

  def new
    @personal_time = Current.user.personal_times.new(kind: "bible_reading", title: PersonalTime::DEFAULT_TITLES["bible_reading"],
                                                     wdays: (0..6).to_a, duration_minutes: 30, zone_shown: zone_shown)
    authorize @personal_time
  end

  def create
    @personal_time = Current.user.personal_times.new(zone_shown:)
    authorize @personal_time

    if @personal_time.plan(personal_time_params, household: Current.household)
      close_dialog_and_refresh
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @personal_time.plan(personal_time_params, household: Current.household)
      close_dialog_and_refresh
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @personal_time.destroy!
    close_dialog_and_refresh
  end

  private
    def set_personal_time
      @personal_time = Current.user.personal_times.find(params[:id])
      @personal_time.zone_shown = zone_shown
      authorize @personal_time
    end

    def personal_time_params
      params.expect(personal_time: [ :kind, :title, :time_of_day, :duration_minutes, :opens_key, :zone_shown, wdays: [] ])
    end

    # The zone a time is saved in: the person's own, or the household's that saving the first one will settle.
    def zone_shown
      Current.user.time_zone || Current.household.time_zone
    end

    def close_dialog_and_refresh
      respond_to do |format|
        format.turbo_stream { render :saved }
        format.html { redirect_to household_calendar_path, status: :see_other }
      end
    end
end
