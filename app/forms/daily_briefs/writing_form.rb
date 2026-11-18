# "Another angle", "Try again", "Write it with AI" (with first) and "Stop" for a daily brief's writings
# (docs/design/daily-brief.md, The brief, its states).
class DailyBriefs::WritingForm < ApplicationForm
  def initialize(label:, first: false, scheme: :default)
    @label = label
    @first = first
    @scheme = scheme
  end

  form do |f|
    f.hidden(name: :first, value: "true") if @first
    f.submit(name: :submit, label: @label, scheme: @scheme)
  end
end
