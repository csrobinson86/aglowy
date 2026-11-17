# "Turn on" and "Turn off" on a child's row in Settings → Children → "Personal study with AI" (frame
# child-study-ai-setting.png). The frame draws a switch; it's a button, because turning it on and off are a create
# and a destroy, and Primer's ToggleSwitch posts to one URL.
class Memberships::StudyAiGrantForm < ApplicationForm
  def initialize(name:, granted:)
    @name = name
    @granted = granted
  end

  form do |f|
    f.submit(name: :submit, label: @granted ? "Turn off" : "Turn on", scheme: @granted ? :default : :primary,
             aria: { label: "#{@granted ? 'Turn off' : 'Turn on'} personal study with AI for #{@name}" })
  end
end
