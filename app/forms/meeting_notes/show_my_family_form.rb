# "Show my family" on the meeting helper's end screen (frame tablet-done.png): shares the note into the household,
# then comes back to the end screen.
class MeetingNotes::ShowMyFamilyForm < ApplicationForm
  def initialize(return_to:)
    @return_to = return_to
  end

  form do |f|
    f.hidden(name: :return_to, value: @return_to)
    f.submit(name: :share, label: "Show my family", scheme: :primary, size: :large, classes: "meeting-helper__button meeting-helper__button--big") do |button|
      button.with_leading_visual_icon(icon: :people)
    end
  end
end
