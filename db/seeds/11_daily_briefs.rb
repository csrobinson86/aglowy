# Sam's daily brief plan, from the husband-and-father starter, so Your plan has its focus areas and week, and today's
# brief from it, so Daily brief opens on one (docs/design/daily-brief.md, Elsewhere; frames brief-plan.png and
# brief-base.png). Plan.start keeps a plan he already has, and DailyBrief.for finds today's brief if it's made.
sam = seeded_person("spouse@example.com")
seeded!(DailyBrief::Plan.start(sam, starter: "husband_and_father"))
seeded!(DailyBrief.for(sam))
