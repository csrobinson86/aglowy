# "Keep in Notes", under the brief (docs/design/daily-brief.md, Keep in Notes, and print).
class DailyBriefs::NoteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Keep in Notes")
  end
end
