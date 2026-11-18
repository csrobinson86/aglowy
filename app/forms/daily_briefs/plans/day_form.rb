# A day's dialog on Your plan (docs/design/daily-brief.md, Your plan): Reading, a box for each focus area that takes a
# topic (Qualities first, as in Your week), Faith examples, then Cancel and Save. Each is optional, as an empty box
# means the brief chooses, and each is sent to the AI as typed, so each says so and asks for no names (Trap 2).
class DailyBriefs::Plans::DayForm < ApplicationForm
  SENT_TO_AI = DailyBriefs::Plans::FocusAreaForm::SENT_TO_AI

  def initialize(dialog_id:, focus_areas:)
    @dialog_id = dialog_id
    @focus_areas = focus_areas
  end

  form do |f|
    day = f.builder.object

    f.text_field(name: :reading, label: "Reading", caption: SENT_TO_AI, maxlength: 120, full_width: true)
    @focus_areas.each do |area|
      # Keyed by the focus area's id, so named in full rather than from a method on the day.
      f.text_field(name: "daily_brief_day[topics][#{area.id}]", id: "daily_brief_day_topics_#{area.id}", scope_name_to_model: false,
                   scope_id_to_model: false, label: area.quality? ? "Qualities" : area.name, value: day.topic_for(area),
                   caption: SENT_TO_AI, maxlength: DailyBrief::Day::TOPIC_MAX, full_width: true)
    end
    f.text_field(name: :examples, label: "Faith examples", caption: SENT_TO_AI, maxlength: 200, full_width: true)
    f.group(layout: :horizontal, justify_content: :flex_end) do |actions|
      actions.button(name: :cancel, label: "Cancel", data: { close_dialog_id: @dialog_id })
      actions.submit(name: :submit, label: "Save #{day.name}", scheme: :primary)
    end
  end
end
