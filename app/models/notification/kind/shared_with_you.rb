# "Daniel shared a meeting note": a member shared a meeting note or a personal goal with the household. It opens the
# note or goal under the notification's own household, and its email waits for the daily summary. A goal's title shows,
# since the household can read it once it's shared; a note's text never does.
class Notification::Kind::SharedWithYou < Notification::Kind
  def icon = :share
  def color = :pink
  def email = :summary

  def title
    "#{actor&.first_name || "Someone"} shared #{goal? ? "a goal" : "a meeting note"}"
  end

  # "Life and Ministry · week of November 16", or the goal's title.
  def body
    if goal?
      subject.title
    else
      "#{MeetingNote::TITLES.fetch(subject.kind)} · week of #{subject.week_of.strftime("%B %-d")}"
    end
  end

  def target_path
    if goal?
      household_goal_path(household_id:, id: subject)
    else
      household_meeting_note_path(household_id:, id: subject)
    end
  end

  private
    def goal?
      subject.is_a?(Goal)
    end
end
