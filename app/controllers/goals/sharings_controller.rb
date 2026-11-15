# Sharing a personal goal with the household in the URL, and stopping. A person in two households shares
# into this one only (docs/design/goals.md, Pages, "Share / stop sharing").
class Goals::SharingsController < ApplicationController
  include HouseholdScoped

  before_action :set_goal

  def create
    @goal.share_with(Current.household)
    redirect_to_goal notice: "Shared with #{Current.household.name}."
  end

  def destroy
    @goal.stop_sharing_with(Current.household)
    redirect_to_goal notice: "Stopped sharing with #{Current.household.name}."
  end

  private

  # Through Current.user, so a family goal, or someone else's goal, is a 404.
  def set_goal
    @goal = Current.user.goals.find(params[:goal_id])
    authorize @goal, :share?
  end

  def redirect_to_goal(notice:)
    redirect_to household_goal_path(id: @goal), notice: notice
  end
end
