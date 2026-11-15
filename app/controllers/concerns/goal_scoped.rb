# Finds the goal in the URL through the membership, so another household's goal, or someone else's
# personal goal, is a 404 (docs/design/goals.md, "Loading a goal"). Each controller authorizes it.
module GoalScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_goal
  end

  private

  def set_goal
    @goal = Goal.reachable_from(Current.membership).find(params[:goal_id])
  end

  def redirect_to_goal(notice:)
    redirect_to household_goal_path(id: @goal), notice: notice
  end
end
