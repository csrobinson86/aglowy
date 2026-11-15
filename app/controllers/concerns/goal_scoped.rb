# Finds the goal in the URL through the membership, so another household's goal, or someone else's
# personal goal, is a 404 (docs/design/goals.md, "Loading a goal"). Marking it complete or archived
# is changing it, so the policy asks update?.
module GoalScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_goal
  end

  private

  def set_goal
    @goal = Goal.reachable_from(Current.membership).find(params[:goal_id])
    authorize @goal, :update?
  end

  def goal_path
    household_goal_path(id: @goal)
  end
end
