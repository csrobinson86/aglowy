# "Prepare today's brief", for someone who wants today's now (docs/design/daily-brief.md, The brief, its states).
class DailyBriefs::PrepareForm < ApplicationForm
  def initialize(scheme: :default)
    @scheme = scheme
  end

  form do |f|
    f.submit(name: :submit, label: "Prepare today's brief", scheme: @scheme)
  end
end
