# Keep in Notes: the brief the page shows, kept as one of the person's own notes, then opened there
# (docs/design/daily-brief.md, Keep in Notes, and print). Heads and adults only, as every brief action is; with no
# written writing the note holds the parts from the plan.
class DailyBriefs::NotesController < ApplicationController
  include HouseholdScoped

  before_action { authorize :daily_brief }

  def create
    # Through Current.user, so it's only ever the person's own.
    if (brief = Current.user.daily_briefs.shown_on(Current.user.today))
      redirect_to household_personal_note_path(id: brief.keep_as_note), notice: "Kept in Notes.", status: :see_other
    else
      redirect_to household_daily_brief_path, alert: "There's no brief to keep yet.", status: :see_other
    end
  end
end
