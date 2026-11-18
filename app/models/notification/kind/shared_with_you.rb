# "Daniel shared a meeting note": a member shared a meeting note, a personal goal or a meeting part with the household.
# It opens what was shared under the notification's own household, and its email waits for the daily summary. A goal's
# title shows, since the household can read it once it's shared; a note's text never does, nor a part's topic,
# preparation or counsel: only its kind and date (docs/design/meeting-parts.md, Sharing; Trap 3).
class Notification::Kind::SharedWithYou < Notification::Kind
  def icon = :share
  def color = :pink
  def email = :summary
  def label = "Shared with you"
  def description = "Someone shares a meeting note, a goal or a meeting part with the household."

  def title
    "#{actor&.first_name || "Someone"} shared #{what}"
  end

  # "Life and Ministry · week of November 16", the goal's title, or "Talk · Thursday, December 10".
  def body
    case subject
    when Goal then subject.title
    when MeetingPart then "#{subject.kind_details.label} · #{subject.meeting_on.strftime("%A, %B %-d")}"
    else "#{MeetingNote::TITLES.fetch(subject.kind)} · week of #{subject.week_of.strftime("%B %-d")}"
    end
  end

  def target_path
    case subject
    when Goal then household_goal_path(household_id:, id: subject)
    when MeetingPart then household_meeting_part_path(household_id:, id: subject)
    else household_meeting_note_path(household_id:, id: subject)
    end
  end

  private
    def what
      case subject
      when Goal then "a goal"
      when MeetingPart then "a meeting part"
      else "a meeting note"
      end
    end
end
