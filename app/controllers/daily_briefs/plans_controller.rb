# The person's daily brief plan: Start, where they pick a starter, and Your plan, where they choose the sections in
# every brief and when it's ready (docs/design/daily-brief.md, Start and Your plan). The plan is the person's, found through Current.user in any
# household they're active in.
class DailyBriefs::PlansController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }
  before_action :set_plan

  def show
    redirect_to new_household_daily_brief_plan_path unless @plan
  end

  # The first starter is chosen to begin with (frame brief-start.png).
  def new
    if @plan
      redirect_to household_daily_brief_plan_path
    else
      @plan = DailyBrief::Plan.new(starter: DailyBrief::Starter.all.first.key)
    end
  end

  # Someone who already has a plan keeps it, whatever was sent.
  def create
    return redirect_to household_daily_brief_plan_path if @plan

    @plan = DailyBrief::Plan.start(Current.user, starter: params.expect(daily_brief_plan: [ :starter ])[:starter])

    if @plan.persisted?
      redirect_to household_daily_brief_plan_path
    else
      render :new, status: :unprocessable_content
    end
  end

  # The sections and "Ready by"; the focus areas have their own dialog. Changes apply from the next brief.
  def update
    raise ActiveRecord::RecordNotFound unless @plan

    if @plan.update(params.expect(daily_brief_plan: [ :ready_at_minutes, sections: [] ]))
      redirect_to household_daily_brief_plan_path, notice: "Plan saved. Your next brief follows it."
    else
      render :show, status: :unprocessable_content
    end
  end

  private
    def set_plan
      @plan = DailyBrief::Plan.preloaded.find_by(user: Current.user)
    end
end
