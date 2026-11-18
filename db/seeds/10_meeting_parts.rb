# Maria's student parts, two coming up and two earlier, one of them shared with the Rivera Family, and one for Lucia, a child with a login (docs/design/meeting-parts.md,
# Elsewhere; frames meeting-parts.png, part-child.png). Each is on a midweek meeting day, counted from the Rivera Family's
# next one. References typed in the preparation are linked on save, as the part's page does.
rivera = seeded_household("The Rivera Family", head: "rivera@example.com")
maria, lucia = seeded_person("rivera@example.com"), seeded_person("lucia.rivera")
next_meeting = rivera.next_midweek_meeting_on || rivera.today

def seed_meeting_part(user, topic:, preparation: nil, **attributes)
  find_seeded(user.meeting_parts.to_a, topic: topic) || user.meeting_parts.new(topic: topic, preparation: preparation, **attributes).tap do |part|
    part.link_scriptures
    part.save!
  end
end

conversation = seed_meeting_part(maria, kind: "starting_a_conversation", meeting_on: next_meeting + 14, minutes: 3, setting: "house_to_house",
  topic: "Start a conversation about hope for the future, and offer to come back.", study_point: "lmd lesson 1 point 3",
  assistant: "Ana Ortiz", preparation: "<p>Good morning. It's been a hard year for many families.</p>" \
    "<p>Do you think problems like these will ever be solved for good? I find one promise comforting: Psalm 37:10, 11.</p>")
seed_meeting_part(maria, kind: "explaining_beliefs_demonstration", meeting_on: next_meeting + 56, minutes: 4,
  topic: "Why we use God's name").share_with(rivera)
seed_meeting_part(maria, kind: "following_up", meeting_on: next_meeting - 56, minutes: 4, setting: "informal_witnessing",
  topic: "Return to someone who asked about prayer.", preparation: "<p>Remind her of what we talked about. Read Philippians 4:6, 7.</p>",
  counsel: "Good, natural conversation. Next: let the scripture do more of the talking.")
seed_meeting_part(maria, kind: "making_disciples", meeting_on: next_meeting - 105, minutes: 5,
  topic: "Lesson on why God made the earth.", counsel: "Clear and warm. Work on asking a viewpoint question first.")

# Her Life and Ministry note for that week, started, so its header shows "Your part this week" (docs/design/meeting-parts.md,
# On the calendar and the meeting note). The parts show on the Rivera Family's calendar in their weeks.
maria.start_meeting_note(kind: "midweek", week_of: conversation.week_of)

seed_meeting_part(lucia, kind: "starting_a_conversation", meeting_on: next_meeting + 28, minutes: 2, setting: "informal_witnessing",
  topic: "Talk to a classmate about what makes a real friend.", study_point: "lmd lesson 2 point 3", assistant: "Dad",
  preparation: "<p>Say hi at lunch. Ask what she likes in a friend.</p><p>Read Proverbs 17:17 and say what I like about it.</p>")

# A drafted AI outline on her Starting a Conversation, which its page shows in the panel, from the saved reply in
# test/fixtures/files/ai/ rather than a provider call (docs/design/meeting-parts.md, Elsewhere). It has no use, so it
# doesn't take one of her 15 requests for today.
unless conversation.drafts.exists?
  body = JSON.parse(Rails.root.join("test/fixtures/files/ai/meeting_part_outline.json").read)
  results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { { url: it["url"], title: it["title"] } }
  conversation.drafts.create!(user: maria, kind: "outline", status: "drafted", chat: Chat.new(user: maria, purpose: MeetingPart::Draft::PURPOSE),
    request: "The person is busy and has a young family.", result: JSON.parse(body["content"].filter_map { it["text"] }.join)["outline"],
    sources: Ai::SourceLink.keep(results, search_results: results, allowed_hosts: Ai::Purpose::ALLOWED_HOSTS))
end
