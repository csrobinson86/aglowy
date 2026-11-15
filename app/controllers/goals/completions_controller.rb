# Marking a goal complete, and reopening it (docs/design/goals.md, Pages, "Complete / reopen").
class Goals::CompletionsController < ApplicationController
  include HouseholdScoped
  include GoalScoped

  before_action { authorize @goal, :update? }

  def create
    @goal.complete(by: Current.user)
    redirect_to_goal notice: "Goal marked complete."
  end

  def destroy
    @goal.reopen
    redirect_to_goal notice: "Goal reopened."
  end
end
