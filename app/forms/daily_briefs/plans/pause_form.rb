# "Pause the daily brief" under Your plan's settings, and "Start it again" in its paused Banner.
class DailyBriefs::Plans::PauseForm < ApplicationForm
  def initialize(label:)
    @label = label
  end

  form do |f|
    f.submit(name: :submit, label: @label)
  end
end
