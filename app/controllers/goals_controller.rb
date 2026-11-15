# Family goals: every member sees the list; heads and adults set new ones (docs/design/goals.md, Pages).
# The tab is a query param on one index. Until a goal has its own page, creating one returns to the list.
class GoalsController < ApplicationController
  include HouseholdScoped

  def index
    authorize Goal
    @status = params[:status].presence_in(Goal::STATUSES) || "active"
    @goals = Current.household.goals.with_status(@status).preloaded
    @counts = Goal::STATUSES.index_with { Current.household.goals.with_status(it).count }
  end

  def new
    @goal = Current.household.goals.new
    authorize @goal
  end

  def create
    @goal = Current.household.goals.new(goal_params.merge(set_by: Current.user))
    authorize @goal

    if @goal.save
      redirect_to household_goals_path, notice: "Goal created."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def goal_params
    params.expect(goal: %i[ title body target_on ])
  end
end
