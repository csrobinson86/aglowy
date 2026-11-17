# The Demo Family's goals: one open with steps (some done, some for named people, one due soon), one completed and
# one archived. Hannah's personal goals: one open with steps, and one shared with the household.
demo = seeded_household("The Demo Family", head: "head@example.com")
head, spouse, charlie = seeded_person("head@example.com"), seeded_person("spouse@example.com"), demo.users.find_by!(name: "Charlie Demo")
today = demo.today

# Titles are encrypted, so a goal is found by its title in Ruby. Steps go on only when the goal is new.
def seed_goal(goals, title:, set_by:, target_on:, body: nil)
  find_seeded(goals, title: title) || goals.create!(title: title, body: body, target_on: target_on, set_by: set_by).tap { yield it if block_given? }
end

seed_goal(demo.goals, title: "Read the Gospels together", set_by: head, target_on: today + 3.months,
  body: "A chapter after dinner, three nights a week.") do |goal|
  goal.add_step(title: "Matthew").tick(for: nil, by: head)
  goal.add_step(title: "Learn the twelve apostles' names", assignees: [ spouse ]).tick(for: spouse, by: spouse)
  goal.add_step(title: "Draw a map of Galilee", assignees: [ charlie ])
  goal.add_step(title: "Mark", due_on: today + 2.weeks)
end

seed_goal(demo.goals, title: "Memorize Psalm 23", set_by: head, target_on: today - 1.month) do |goal|
  goal.add_step(title: "Say it together at breakfast").tick(for: nil, by: head)
  goal.complete(by: head)
end

seed_goal(demo.goals, title: "Visit the Bethel tour", set_by: spouse, target_on: today + 1.year) do |goal|
  goal.archive(by: head)
end

seed_goal(head.goals, title: "Read the whole Bible this year", set_by: head, target_on: today.end_of_year) do |goal|
  goal.add_step(title: "Genesis to Deuteronomy").tick(for: nil, by: head)
  goal.add_step(title: "Joshua to Esther", due_on: today + 1.month)
  goal.tag_with("faith", by: head)
end

seed_goal(head.goals, title: "Start one Bible study", set_by: head, target_on: today + 6.months) do |goal|
  goal.tag_with("ministry", by: head)
  goal.share_with(demo)
end
