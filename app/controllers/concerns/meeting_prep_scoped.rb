# Get ready's pages (docs/design/meeting-prep.md, Pages and routes): this week's cards, the Monday where the household
# lives (Trap 7), in the meeting helper's layout for a child and the household layout for a head or adult. Anyone
# MeetingPrepPolicy turns away gets a 404, not the usual redirect, as on the helper's own pages.
module MeetingPrepScoped
  extend ActiveSupport::Concern

  included do
    include HouseholdScoped

    # Rails' layout takes no if:, so a block picks it.
    layout -> { Current.membership.child? ? "meeting_helper" : "household" }

    rescue_from(Pundit::NotAuthorizedError) { raise ActiveRecord::RecordNotFound }

    before_action :authorize_meeting_prep
    before_action :set_prep_week

    helper_method :cards_for
  end

  private

  def authorize_meeting_prep
    authorize Current.household, policy_class: MeetingPrepPolicy
  end

  def set_prep_week
    @week_of = Current.household.prep_week_of
    @prep_week = Current.household.prep_week_for(@week_of)
  end

  # A meeting's cards this week in step order, none while the week has none. A meeting that isn't midweek or weekend
  # is a 404.
  def cards_for(meeting)
    raise ActiveRecord::RecordNotFound, "No meeting #{meeting.inspect}" unless meeting.in?(Household::MEETING_KINDS)

    Array(@prep_week&.cards_for(meeting))
  end

  # A meeting's card for a step this week. A step with no card is a 404.
  def card_for(meeting, step)
    cards_for(meeting).find { it.step == step } or raise ActiveRecord::RecordNotFound, "No card for #{step.inspect}"
  end
end
