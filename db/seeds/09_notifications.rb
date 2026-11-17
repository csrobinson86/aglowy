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
