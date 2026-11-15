# Ticking and unticking a step from its goal's page (docs/design/goals.md, Pages, "Tick / untick").
# user_id names whose part; blank means done together. Answers with Turbo Streams: the step's row and the progress box.
class Goals::Steps::CompletionsController < ApplicationController
  include HouseholdScoped

  before_action :set_step

  # The person is found among the step's people, so anyone else is a 404. Whether this person may tick
  # their part is the policy's question.
  def create
    user = @step.assignees.find(params[:user_id]) if params[:user_id].present?
    authorize @step.new_tick(user&.id)
    @step.tick(for: user, by: Current.user)
    render_changes
  end

  # Through the step, so another step's tick is a 404.
  def destroy
    completion = @step.completions.find(params[:id])
    authorize completion
    @step.untick(for: completion.user)
    render_changes
  end

  private

  # Through the membership, then the goal, so another household's goal or step is a 404.
  def set_step
    @step = Goal.reachable_from(Current.membership).find(params[:goal_id]).steps.find(params[:step_id])
  end

  def render_changes
    @goal = Goal.reachable_from(Current.membership).preloaded.find(@step.goal_id)
    @step = @goal.steps.find { it.id == @step.id }
    render :changes
  end
end
