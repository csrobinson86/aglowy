# The person's study guide (docs/design/study-guide.md, Pages and routes): this week's, or the not-made-yet state with
# the weeks kept, and a week's guide a meeting at a time. Found through Current.user, so another person's week is a 404
# like a week with none (Trap 3). Anyone StudyGuidePolicy turns away gets a 404 too, not the usual redirect.
class StudyGuidesController < ApplicationController
  include HouseholdScoped

  rescue_from(Pundit::NotAuthorizedError) { raise ActiveRecord::RecordNotFound }

  before_action :no_store # It's personal: Back, which skips revalidating, can't show it to the next person to sign in.

  # This week is the Monday where the person lives, as the weekly job makes it (Trap 6).
  def index
    authorize :study_guide
    week_of = Current.user.study_guide_week

    if Current.user.study_guide_for?(week_of)
      redirect_to household_study_guide_path(week_of:)
    else
      @study_guides = Current.user.study_guides.order(week_of: :desc)
    end
  end

  # A week_of that isn't a date is cast to none, and finds no guide.
  def show
    @study_guide = Current.user.study_guides.preloaded.find_by!(week_of: params[:week_of])
    authorize @study_guide
    @meeting = params[:meeting] == "weekend" ? "weekend" : "midweek"
    # The children's cards are the household's in the URL, never the guide's (docs/design/study-guide.md, Trap 4).
    @prep_cards = Current.household.prep_cards_by_step(@study_guide.week_of)
  end
end
