# Marking a goal complete, and reopening it (docs/design/goals.md, Pages, "Complete / reopen").
class Goals::CompletionsController < ApplicationController
  include HouseholdScoped
  include GoalScoped

  def create
    @goal.complete(by: Current.user)
    redirect_to goal_path, notice: "Goal marked complete."
  end

  def destroy
    @goal.reopen
    redirect_to goal_path, notice: "Goal reopened."
  end
end
