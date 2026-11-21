class FamilyStudiesController < ApplicationController
  include HouseholdScoped

  before_action { authorize FamilyStudy }
  before_action -> { set_goal_step(params[:goal_step_id]) }, only: :new
  before_action -> { set_goal_step(scheduling_params[:goal_step_id]) }, only: :create

  def index
    @sessions = Current.household.family_study_sessions.ahead.preloaded.limit(10)
  end

  # Also reloads the Repeat field's Turbo Frame when the date changes, so the choices come from the server.
  # ?from_study= is "Create family study" (docs/design/personal-study.md, Create family study): found through
  # Current.user, so someone else's study is ignored.
  def new
    @scheduling = FamilyStudy::Scheduling.new(household: Current.household, **repeat_field_params)
    @scheduling.fill_in_from(@goal_step) if @goal_step
    @from_study = Current.user.personal_studies.find_by(id: params[:from_study]) if params[:from_study].present?
  end

  def create
    @scheduling = FamilyStudy::Scheduling.new(household: Current.household, **scheduling_params)
    @scheduling.link_scriptures

    if @scheduling.save
      if @goal_step
        redirect_to household_goal_path(id: @goal_step.goal_id), notice: "The study is scheduled and linked to this step."
      else
        redirect_to household_family_studies_path, notice: "Your family study is scheduled."
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # Scheduling a goal step as a study: found through the household's goals, so another family's step is a 404,
  # and only on a goal its person may still change (docs/design/goals.md, Traps).
  def set_goal_step(id)
    if id.present?
      @goal_step = Current.household.goal_steps.find(id)
      authorize @goal_step, :update?
    end
  end

  # Present only when the Repeat field reloads for a new date.
  def repeat_field_params
    params.permit(family_study_scheduling: %i[ starts_on repeat ])[:family_study_scheduling] || {}
  end

  def scheduling_params
    params.expect(family_study_scheduling: [ :topic, :starts_on, :starts_at, :ends_at, :repeat, :notes, :link_url, :goal_step_id, link_urls: [], files: [] ])
  end
end
