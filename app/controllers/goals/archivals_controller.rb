# Archiving a goal to look back on, and restoring it (docs/design/goals.md, Pages, "Archive / restore").
# A restored goal goes back to the tab its completion decides. A personal goal goes to My goals' Archived tab.
class Goals::ArchivalsController < ApplicationController
  include HouseholdScoped
  include GoalScoped

  before_action { authorize @goal, :update? }

  def create
    @goal.archive(by: Current.user)
    redirect_to helpers.goal_list_path(@goal, status: "archived"), notice: "Goal archived."
  end

  def destroy
    @goal.restore
    redirect_to_goal notice: "Goal restored."
  end
end
