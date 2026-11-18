# "Keep in Notes", under the brief, with the date of the brief the page shows (docs/design/daily-brief.md, Keep in Notes,
# and print).
class DailyBriefs::NoteForm < ApplicationForm
  def initialize(on:)
    @on = on
  end

  form do |f|
    f.hidden(name: :on, value: @on.iso8601)
    f.submit(name: :submit, label: "Keep in Notes")
  end
end
