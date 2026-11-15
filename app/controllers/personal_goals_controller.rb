# A person's own goals. They're the same in every household the person belongs to, so they're reached
# through Current.user, never Current.household (docs/design/goals.md, Pages, "My goals"). Each one opens
# at /goals/:id, where GoalsController finds it through Goal.reachable_from. The Shared tab lists the
# personal goals others shared into this household.
class PersonalGoalsController < ApplicationController
  include HouseholdScoped

  STATUSES = Goal::STATUSES + %w[ shared ]

  def index
    authorize Goal
    @status = params[:status].presence_in(STATUSES) || "active"
    @goals = goals_with_status(@status).preloaded
    @counts = STATUSES.index_with { goals_with_status(it).count }
  end

  def new
    @goal = Current.user.goals.new
    authorize @goal
  end

  def create
    @goal = Current.user.goals.new(params.expect(goal: %i[ title body target_on ]).merge(set_by: Current.user))
    authorize @goal

    if @goal.save
      redirect_to household_goal_path(id: @goal), notice: "Goal created."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # Shared goals sort by target date, like the Active tab; titles are encrypted.
  def goals_with_status(status)
    if status == "shared"
      Goal.shared_with(Current.household).where.not(user: Current.user).order(:target_on)
    else
      Current.user.goals.with_status(status)
    end
  end
end
