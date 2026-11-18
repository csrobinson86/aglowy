# Sam's daily brief plan, from the husband-and-father starter, so Your plan has its focus areas and week, and today's
# brief from it, so Daily brief opens on one and his Home has its card (docs/design/daily-brief.md, Elsewhere; frames
# brief-plan.png, brief-home.png and
# brief-today.png). Plan.start keeps a plan he already has, and DailyBrief.for finds today's brief if it's made, or
# makes none if he's paused his plan.
sam = seeded_person("spouse@example.com")
plan = seeded!(DailyBrief::Plan.start(sam, starter: "husband_and_father"))

# His own goal, linked to Reaching out, so the plan shows "Linked to your goal" and the brief its next step (the story,
# #310; frames brief-plan.png and brief-today.png). A goal he already has keeps its steps, and a link he changed to another goal stays.
serving = seed_goal(sam.goals, title: "Qualify as a ministerial servant", set_by: sam, target_on: sam.today + 1.year) do |goal|
  goal.add_step(title: "Read 1 Timothy 3 and Titus 1").tick(for: nil, by: sam)
  goal.add_step(title: "Ask an elder where I can help")
end
plan.focus_areas.find { it.name == "Reaching out" && it.goal_id.nil? }&.update!(goal: serving) if serving.open?
brief = DailyBrief.for(sam)

# Today's brief written by AI, from the saved reply in test/fixtures/files/ai/ rather than a provider call. It has no
# use, so it doesn't take one of his 3 for today. As check 4 does, the Daily text is kept only on the day that reply
# read, and otherwise the brief shows the link alone.
if brief && brief.writings.none?
  body = JSON.parse(Rails.root.join("test/fixtures/files/ai/daily_brief.json").read)
  results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { { url: it["url"], title: it["title"] } }
  sources = Ai::SourceLink.keep(results, search_results: results, allowed_hosts: Ai::Purpose::ALLOWED_HOSTS)
  result = JSON.parse(body["content"].filter_map { it["text"] }.join).except("off_topic")
  result.delete("daily_text") unless sources.any? { it[:url] == brief.daily_text_url }

  brief.writings.create!(status: "written", chat: Chat.new(user: sam, purpose: DailyBrief::Writing::PURPOSE), result:, sources:)
end

# Shared with the Demo Family, so Hannah's Home has Today's thought (For the children, and sharing; frame
# brief-family.png). Sharing again finds the same sharing.
brief&.share_with(seeded_household("The Demo Family", head: "head@example.com"))
