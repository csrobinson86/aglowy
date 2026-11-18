# Share with the family and Stop sharing: today's thought, from the person's own brief for today, with the household in
# the URL only (docs/design/daily-brief.md, For the children, and sharing). Heads and adults only, as every brief action
# is; a brief that hasn't been written has no thought to share.
class DailyBriefs::SharingsController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }
  before_action :set_brief

  def create
    if @brief&.writing
      @brief.share_with(Current.household)
      redirect_to brief_path, notice: "Shared with #{Current.household.name}.", status: :see_other
    else
      redirect_to brief_path, alert: "Today's brief hasn't been written, so there's nothing to share.", status: :see_other
    end
  end

  def destroy
    @brief&.stop_sharing_with(Current.household)
    redirect_to brief_path, notice: "Stopped sharing with #{Current.household.name}.", status: :see_other
  end

  private
    # Through Current.user, so it's only ever the person's own.
    def set_brief
      @brief = Current.user.daily_briefs.find_by(on: Current.user.today)
    end

    # Back to the part it was shared from, morning or evening.
    def brief_path
      household_daily_brief_path(part: params[:part].presence_in(%w[ evening ]))
    end
end
