# Family goals: every member sees the list and each goal; heads and adults set and edit them
# (docs/design/goals.md, Pages). The tab is a query param on one index.
class GoalsController < ApplicationController
  include HouseholdScoped

  def index
    authorize Goal
    @status = params[:status].presence_in(Goal::STATUSES) || "active"
    @goals = Current.household.goals.with_status(@status).preloaded
    @counts = Goal::STATUSES.index_with { Current.household.goals.with_status(it).count }
  end

  def show
    @goal = reachable_goals.preloaded.find(params[:id])
    authorize @goal
  end

  def new
    @goal = Current.household.goals.new
    authorize @goal
  end

  def create
    @goal = Current.household.goals.new(goal_params.merge(set_by: Current.user))
    authorize @goal

    if @goal.save
      redirect_to household_goal_path(id: @goal), notice: "Goal created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Someone who can't edit has no edit page, so it's a 404 like any page that isn't theirs (story #92).
  # Updating refuses them like any other write.
  def edit
    @goal = reachable_goals.find(params[:id])
    authorize @goal, :show?
    raise ActiveRecord::RecordNotFound unless policy(@goal).edit?
  end

  # The form carries lock_version, so a second editor's save shows the first one's values instead of overwriting them.
  def update
    @goal = reachable_goals.find(params[:id])
    authorize @goal

    if @goal.update(params.expect(goal: %i[ title body target_on lock_version ]))
      redirect_to household_goal_path(id: @goal), notice: "Goal updated."
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::StaleObjectError
    @goal.reload
    @stale = true
    render :edit, status: :conflict
  end

  # Steps, assignments, ticks, the completion and the archival go with it (cascading foreign keys).
  def destroy
    @goal = reachable_goals.find(params[:id])
    authorize @goal
    @goal.delete_for_good
    redirect_to helpers.goal_list_path(@goal), notice: "Goal deleted."
  end

  private

  # Through the membership, so another household's goal, or someone else's personal goal, is a 404.
  def reachable_goals
    Goal.reachable_from(Current.membership)
  end

  def goal_params
    params.expect(goal: %i[ title body target_on ])
  end
end
