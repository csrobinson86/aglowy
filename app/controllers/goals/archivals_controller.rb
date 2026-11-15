# Archiving a goal to look back on, and restoring it (docs/design/goals.md, Pages, "Archive / restore").
# A restored goal goes back to the tab its completion decides.
class Goals::ArchivalsController < ApplicationController
  include HouseholdScoped
  include GoalScoped

  def create
    @goal.archive(by: Current.user)
    redirect_to household_goals_path(status: "archived"), notice: "Goal archived."
  end

  def destroy
    @goal.restore
    redirect_to goal_path, notice: "Goal restored."
  end
end
