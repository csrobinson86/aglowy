# "Pause the daily brief" under Your plan's settings, and "Start it again" in its paused Banner.
class DailyBriefs::Plans::PauseForm < ApplicationForm
  def initialize(label:, autofocus: false)
    @label = label
    @autofocus = autofocus
  end

  form do |f|
    f.submit(name: :submit, label: @label, autofocus: @autofocus)
  end
end
