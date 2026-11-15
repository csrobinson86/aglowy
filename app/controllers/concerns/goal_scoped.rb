# Finds the goal in the URL through the membership, so another household's goal, or someone else's
# personal goal, is a 404 (docs/design/goals.md, "Loading a goal"). A goal shared with the person is
# read-only, so changing it is a 404 too. Each controller authorizes it.
module GoalScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_goal
  end

  private

  def set_goal
    @goal = Goal.family_or_own(Current.membership).find(params[:goal_id])
  end

  def redirect_to_goal(notice:)
    redirect_to household_goal_path(id: @goal), notice: notice
  end
end
