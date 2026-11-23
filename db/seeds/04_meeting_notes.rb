# Hannah's notes: this week's Life and Ministry note started and the Weekend one not, then fourteen earlier weeks, enough
# for Older weeks on the Meeting notes tab: both meetings each week but the fourth, which has only Life and Ministry.
# One of hers and one of Sam's are shared with the Demo Family. Lucia used the meeting helper last week and showed
# her family, so Maria has a helper note to read.
demo, rivera = seeded_household("The Demo Family", head: "head@example.com"), seeded_household("The Rivera Family", head: "rivera@example.com")
head, spouse, lucia = seeded_person("head@example.com"), seeded_person("spouse@example.com"), seeded_person("lucia.rivera")

# Fills a note just started, as the edit form does: parts by key, references in the notes linked on save.
def seed_meeting_note(user, kind:, week_of:, parts: {}, gems: [])
  note = user.start_meeting_note(kind: kind, week_of: week_of)
  return note if note.gems.any? || note.parts.any?(&:filled?)

  note.revise!(
    parts_attributes: parts.map { |key, fields| { id: note.parts.find { it.key == key.to_s }.id, **fields } },
    gems_attributes: gems.map { |scripture, insight| { scripture: scripture, insight: insight } }
  ) { it.parts.each(&:link_scriptures) }
  note
end

this_week = demo.today.beginning_of_week(:monday)

seed_meeting_note(head, kind: "midweek", week_of: this_week,
  parts: { talk: { title: "Keep on the Watch", notes: "<p>Staying awake spiritually, as in Matt 24:42. Personal study comes first.</p>" },
           bible_reading: { notes: "<p>Notice how patient Jehovah was with Israel.</p>" } },
  gems: [ [ "Isaiah 41:10", "Jehovah doesn't just tell us not to fear; he says he will hold on to us." ],
          [ "Isa 40:29", "Strength is given to the tired, not to those who are already strong." ] ])

earlier = (1..14).map { this_week - it.weeks }
earlier.each_with_index do |week_of, index|
  seed_meeting_note(head, kind: "midweek", week_of: week_of,
    parts: { talk: { title: "Sample talk #{index + 1}", notes: "<p>Main point: trust Jehovah, Prov 3:5, 6.</p>" } },
    gems: [ [ "Psalm 23:1", "Sample gem: a shepherd who lacks nothing for his sheep." ] ])
  next if index == 3

  seed_meeting_note(head, kind: "weekend", week_of: week_of,
    parts: { public_talk: { title: "Sample public talk #{index + 1}", speaker: "Brother Sample", notes: "<p>Read Rom 12:11 together.</p>" },
             watchtower_study: { title: "Sample study article #{index + 1}", notes: "<p>Paragraph 7 was a good one to comment on.</p>" } })
end

head.meeting_notes.find_by!(kind: "weekend", week_of: earlier.second).share_with(demo)
head.meeting_notes.find_by!(kind: "midweek", week_of: earlier.first).tag_with("faith", by: head)
head.meeting_notes.find_by!(kind: "weekend", week_of: earlier.first).tag_with("ministry", by: head)

seed_meeting_note(spouse, kind: "weekend", week_of: earlier.first,
  parts: { public_talk: { title: "Sample public talk 1", speaker: "Brother Sample", notes: "<p>The talk on Ps 37:29 was encouraging.</p>" } })
  .share_with(demo)

helper_note = lucia.start_meeting_note(kind: "midweek", week_of: rivera.today.beginning_of_week(:monday) - 1.week)
%w[ opening_song talk spiritual_gems bible_reading closing_song ].each { helper_note.mark(it) }
helper_note.share_with(rivera)
