# Your plan's own settings (docs/design/daily-brief.md, Your plan; frame brief-plan.png): the five sections in every
# brief, "Ready by" from 4:00 to 8:00 AM on the half hour, and Save plan. A section at a time, so What's sent to the AI
# can sit beside them. The empty sections[] says the form was sent even with nothing ticked.
class DailyBriefs::PlanForm < ApplicationForm
  SECTIONS = {
    "daily_text" => [ "Daily text", "A link to the day's text, and three things to think about." ],
    "reading" => [ "Bible reading", "One passage from the day's books, with what to look for." ],
    "faith_example" => [ "Imitate their faith", "One lesson from the day's example." ],
    "children" => [ "For the children", "A question to ask and something to do. You choose each day whether to share it with the household." ],
    "evening" => [ "Evening questions", "Three or four questions that open at 6:00 PM. Answers are never saved." ]
  }.freeze

  # section: :sections, :ready_by or :submit. Only :ready_by needs time_zone, the person's, which it names.
  def initialize(section:, time_zone: nil)
    @section = section
    @time_zone = time_zone
  end

  form do |f|
    plan = f.builder.object

    case @section
    when :sections
      f.hidden(name: :sections, value: "", multiple: true, id: "daily_brief_plan_sections_sent")
      f.check_box_group(name: :sections, label: "In every brief", visually_hide_label: true) do |group|
        SECTIONS.each do |value, (label, caption)|
          group.check_box(value:, label:, caption:, checked: value.in?(plan.sections))
        end
      end
    when :ready_by
      f.select_list(name: :ready_at_minutes, label: "Ready by", caption: "In your time zone, #{@time_zone}.") do |list|
        DailyBrief::Plan::READY_AT_MINUTES.each { list.option(label: plan.ready_by(it), value: it) }
      end
    when :submit
      f.submit(name: :submit, label: "Save plan", scheme: :primary)
    end
  end
end
