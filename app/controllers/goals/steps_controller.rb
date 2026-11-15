# Adding, editing and removing a goal's steps from its page (docs/design/goals.md, Pages, "Steps").
# Each change answers with Turbo Streams: the steps and the progress box, or the one form again when it failed.
class Goals::StepsController < ApplicationController
  include HouseholdScoped

  before_action :set_goal
  before_action :set_step, only: %i[ update destroy ]

  def create
    authorize Goal::Step.new(goal: @goal)
    @goal.add_step(title: step_params[:title], due_on: step_params[:due_on], assignees: assignees)
    render_changes
  rescue ActiveRecord::RecordInvalid => error
    render turbo_stream: turbo_stream.replace("new-goal-step", partial: "goals/steps/new", locals: { goal: @goal, step: error.record }),
           status: :unprocessable_content
  end

  def update
    @step.revise(title: step_params[:title], due_on: step_params[:due_on], assignees: assignees, lock_version: step_params.fetch(:lock_version))
    render_changes
  rescue ActiveRecord::RecordInvalid
    render_step status: :unprocessable_content, checked_ids: assignee_ids
  rescue ActiveRecord::StaleObjectError
    @step = @goal.steps.find(@step.id)
    render_step status: :conflict, stale: true
  end

  def destroy
    @step.remove
    render_changes
  end

  private

  # Through the membership, so another household's goal is a 404.
  def set_goal
    @goal = Goal.reachable_from(Current.membership).find(params[:goal_id])
  end

  # Through the goal, so another goal's step is a 404.
  def set_step
    @step = @goal.steps.find(params[:id])
    authorize @step
  end

  def step_params
    params.expect(goal_step: [ :title, :due_on, :lock_version, assignee_ids: [] ])
  end

  # Found by id, then checked as active members of the goal's household under its lock when assigned
  # (Goal::Step::Assignment), so anyone else makes the step invalid. No ids means Everyone.
  def assignees
    User.where(id: assignee_ids)
  end

  def assignee_ids
    step_params.fetch(:assignee_ids, []).compact_blank
  end

  def render_changes
    @goal = Goal.reachable_from(Current.membership).preloaded.find(@goal.id)
    render :changes
  end

  # A failed edit shows the people the user ticked; a stale one shows the step as it is now.
  def render_step(status:, stale: false, checked_ids: nil)
    render turbo_stream: turbo_stream.replace(@step, partial: "goals/steps/step", locals: { step: @step, editable: true, editing: true, stale:, checked_ids: }),
           status: status
  end
end
