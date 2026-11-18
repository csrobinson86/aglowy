# "Share with the family" and "Stop sharing" for today's thought, in the brief's children's box. From the evening,
# part takes it back to the evening.
class DailyBriefs::SharingForm < ApplicationForm
  def initialize(label:, evening: false)
    @label = label
    @evening = evening
  end

  form do |f|
    f.hidden(name: :part, value: "evening") if @evening
    f.submit(name: :submit, label: @label)
  end
end
