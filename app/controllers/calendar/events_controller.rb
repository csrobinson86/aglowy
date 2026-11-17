# Adding, editing and deleting a household event, in a dialog loaded into the calendar's Turbo Frame
# (docs/design/calendar.md, The household event dialog). A refused save shows the dialog again with the reasons; a saved
# one closes it and refreshes the calendar, whose URL alone knows the week, the view and what's hidden.
class Calendar::EventsController < ApplicationController
  include HouseholdScoped

  before_action :set_event, only: %i[ edit update destroy ]

  # Also what the Repeats frame reloads with a new date, keeping the choice made.
  def new
    @event = Current.household.events.new(kind: "circuit_assembly", title: Household::Event.default_title("circuit_assembly"),
                                          starts_on: Current.household.today, **params.fetch(:household_event, {}).permit(:starts_on, :repeat))
    authorize @event
  end

  def create
    @event = Current.household.events.new(created_by: Current.user)
    authorize @event

    if @event.schedule(event_params)
      close_dialog_and_refresh
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @event.schedule(event_params)
      close_dialog_and_refresh
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @event.destroy!
    close_dialog_and_refresh
  end

  private
    # Through Current.household, so another household's event is a 404.
    def set_event
      @event = Current.household.events.find(params[:id])
      authorize @event
    end

    def event_params
      params.expect(household_event: %i[ kind title all_day starts_on ends_on starts_at ends_at repeat location note ])
    end

    def close_dialog_and_refresh
      respond_to do |format|
        format.turbo_stream { render :saved }
        format.html { redirect_to household_calendar_path, status: :see_other }
      end
    end
end
