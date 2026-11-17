# "Tuesday's family study has no topic yet": a session three days ahead with no topic, for the household's heads. It
# opens the session, and its email goes right away.
class Notification::Kind::StudyTopicNeeded < Notification::Kind
  def icon = :book
  def color = :blue
  def email = :right_away

  def title
    "#{subject.local_scheduled_at.strftime("%A")}'s family study has no topic yet"
  end

  def body
    "Choose a topic, or draft one with AI, before #{subject.local_scheduled_at.strftime("%A, %B %-d")}."
  end

  def target_path
    household_family_study_session_path(household_id:, family_study_id: subject.family_study_id, id: subject)
  end
end
