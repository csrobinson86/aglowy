class DashboardsController < ApplicationController
  include HouseholdScoped

  # Each list is one limited query; the Welcome empty state reuses them rather than asking again.
  def show
    authorize Current.household, :show?
    @next_session, *@coming_up = Current.household.family_study_sessions.upcoming.preloaded.limit(4)
    @family_goals = Current.household.goals.active.includes(:set_by).limit(3).load
    @my_goals = Current.user.goals.active.limit(3).load
    @meeting_notes = Current.user.meeting_notes.newest_first.limit(2).load
    @pinned_notes = Current.user.personal_notes.pinned.limit(5).load
    @welcome = [ @next_session, @family_goals, @my_goals, @meeting_notes, @pinned_notes ].all?(&:blank?)
    @todays_meeting = Current.household.current_or_next_meeting if Current.household.meeting_day?
    @daily_brief = todays_daily_brief
    @shared_thoughts = shared_thoughts
    no_store if @daily_brief # As on the brief's page: Back can't show it to the next person to sign in.
  end

  private
    # The signed-in person's own brief for today, never another member's. Showing its card counts as seeing it, so
    # someone who reads the card each day isn't paused (docs/design/daily-brief.md, On Home; Trap 5).
    def todays_daily_brief
      return unless policy(:daily_brief).show?

      Current.user.daily_brief_plan&.todays_brief&.tap(&:mark_seen)
    end

    # Today's thought from each other member who shared their brief here today, written; never the viewer's own, and
    # never marked seen, as only the owner's own page or card counts (docs/design/daily-brief.md, For the children, and
    # sharing; Traps 5 and 8). Children see them too.
    def shared_thoughts
      DailyBrief.shared_with(Current.household).where(on: Current.household.today).where.not(user: Current.user)
        .includes(:user, :writings).order(:created_at).select(&:writing)
    end

    # Start for a child with the helper, Open my notes for everyone else (docs/design/meeting-helper.md, Pages).
    def meeting_helper?
      MeetingHelperPolicy.new(pundit_user, Current.household).show?
    end
    helper_method :meeting_helper?
end
