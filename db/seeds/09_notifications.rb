# Maria's inbox in the Rivera Family (docs/design/notifications.md, Elsewhere; frame notifications.png). Lucia's helper
# note, shared in 04_meeting_notes.rb, already told her. Here Sam shares two meeting notes and a goal; sharing makes each
# notification through user.notify, as in the app. They're dated back over the week, and the two oldest are read.
# Settings stay off, as for a new person.
rivera = seeded_household("The Rivera Family", head: "rivera@example.com")
maria, spouse = seeded_person("rivera@example.com"), seeded_person("spouse@example.com")
this_week = rivera.today.beginning_of_week(:monday)

shares = {
  seed_meeting_note(spouse, kind: "midweek", week_of: this_week - 1.week,
    parts: { talk: { title: "Sample talk", notes: "<p>Trust Jehovah, Prov 3:5, 6.</p>" } }) => 4.days,
  seed_goal(spouse.goals, title: "Read the Gospels by March", set_by: spouse, target_on: Date.new(rivera.today.year + 1, 3, 31)) => 2.days,
  seed_meeting_note(spouse, kind: "midweek", week_of: this_week,
    parts: { talk: { title: "Keep on the Watch", notes: "<p>Stay awake, Matt 24:42.</p>" } }) => 2.hours
}

shares.each do |subject, ago|
  subject.share_with(rivera)
  notification = maria.notifications.find_by!(subject:)
  notification.update_column(:created_at, ago.ago)
  notification.read if ago > 1.day
end

# The three scheduled kinds, as the jobs would make them (docs/design/notifications.md, Recurring jobs): last Sunday's
# look at this week, a session three days out with no topic yet, and an invitation Maria sent five days ago. Unread.
week = maria.notify(kind: "weekly_preview", household: rivera, subject: rivera, data: { week_of: this_week },
  dedupe_key: "weekly_preview:#{rivera.id}:#{this_week}")
week.update_column(:created_at, ActiveSupport::TimeZone[rivera.time_zone].local(this_week.year, this_week.month, this_week.day) - 6.hours)

session = rivera.family_study_sessions.upcoming.without_topic.first
maria.notify(kind: "study_topic_needed", household: rivera, subject: session, dedupe_key: "study_topic_needed:#{session.id}")

invitation = rivera.invitations.find_by(email: "grandpa@example.com") ||
  rivera.invitations.create!(email: "grandpa@example.com", invited_by: maria).tap { it.update_columns(created_at: 5.days.ago, expires_at: 2.days.from_now) }
maria.notify(kind: "invitation_unaccepted", household: rivera, subject: invitation, dedupe_key: "invitation_unaccepted:#{invitation.id}")
