# The household's calendar, a week or a month at a time (docs/design/calendar.md, The page). The URL is the whole state:
# ?view=week|month&date=2026-11-17&hide[]=meetings. The Show form sends the groups it ticks as show[], and is sent on
# to the same page with the others in hide[], so every link on it reads the same way.
class CalendarsController < ApplicationController
  include HouseholdScoped

  before_action { authorize Current.household, policy_class: CalendarPolicy }

  def show
    @period = Household::Calendar::Period.new(view: view, date: date)

    if params.key?(:show)
      redirect_to helpers.calendar_page_path(@period.view, @period.date, hide: Household::Calendar.group_keys - Array(params[:show]))
    else
      @hide = Array(params[:hide]) & Household::Calendar.group_keys
      @calendar = Household::Calendar.new(Current.household, viewer: Current.user, range: @period.range, hide: @hide)
      @meeting_helper = MeetingHelperPolicy.new(pundit_user, Current.household).show?
    end
  end

  private
    def view
      params[:view].presence_in(Household::Calendar::Period::VIEWS) || "week"
    end

    # Today where the household lives, unless the URL names a date. Date::Error is an ArgumentError, and the date gem
    # raises a plain ArgumentError for a string over 128 characters.
    def date
      Date.iso8601(params[:date].to_s)
    rescue ArgumentError
      Current.household.today
    end
end
