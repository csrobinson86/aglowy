# Start (frame brief-start.png): the four starters as a radio group, each with its focus areas, then Start my daily
# brief. A section at a time, so the AI notice can sit between them.
class DailyBriefs::StartForm < ApplicationForm
  # section: :starters or :submit.
  def initialize(section:)
    @section = section
  end

  form do |f|
    case @section
    when :starters
      f.radio_button_group(name: :starter, label: "Start from a plan", caption: "Every part of the plan can be changed afterwards.") do |starters|
        DailyBrief::Starter.all.each do |starter|
          starters.radio_button(value: starter.key, label: starter.name, caption: starter.description)
        end
      end
    when :submit
      f.submit(name: :submit, label: "Start my daily brief", scheme: :primary)
    end
  end
end
