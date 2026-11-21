# Get my comment ready, or Draw it!, on a Get ready card (frames tablet-prep-study-comment.png, tablet-prep-reading.png):
# posts to her note for the meeting with what to open next (docs/design/meeting-prep.md, Pages and routes).
class MeetingPreps::NoteForm < ApplicationForm
  LABELS = { "answer" => "Get my comment ready", "drawing" => "Draw it!" }.freeze

  def initialize(to:)
    @to = to
  end

  form do |f|
    f.hidden(name: :to, value: @to)
    f.submit(name: :open, label: LABELS.fetch(@to), scheme: @to == "answer" ? :primary : :default, size: :large,
             classes: [ "meeting-helper__button", "meeting-helper__button--step", { "meeting-prep__go": @to == "answer" } ]) do |button|
      button.with_leading_visual_icon(icon: :pencil)
    end
  end
end
