class FamilyStudiesController < ApplicationController
  include HouseholdScoped

  before_action { authorize FamilyStudy }

  def index
    @sessions = Current.household.family_study_sessions.ahead.preloaded.limit(10)
  end

  # Also reloads the Repeat field's Turbo Frame when the date changes, so the choices come from the server.
  def new
    @scheduling = FamilyStudy::Scheduling.new(household: Current.household, **repeat_field_params)
  end

  def create
    @scheduling = FamilyStudy::Scheduling.new(household: Current.household, **scheduling_params)

    if @scheduling.save
      redirect_to household_family_studies_path, notice: "Your family study is scheduled."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # Present only when the Repeat field reloads for a new date.
  def repeat_field_params
    params.permit(family_study_scheduling: %i[ starts_on repeat ])[:family_study_scheduling] || {}
  end

  def scheduling_params
    params.expect(family_study_scheduling: [ :topic, :starts_on, :starts_at, :ends_at, :repeat, :notes, :link_url, link_urls: [], files: [] ])
  end
end
