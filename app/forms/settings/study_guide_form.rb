# Settings → You → Study guide (docs/design/study-guide.md, The Settings section; frame phone-guide-settings.png). Without
# accepted AI terms the box is disabled and there's nothing to save; the view says where to accept them.
class Settings::StudyGuideForm < ApplicationForm
  def initialize(on:, disabled:)
    @on = on
    @disabled = disabled
  end

  form do |f|
    f.check_box(name: :enabled, label: "Make me a study guide each week", checked: @on, disabled: @disabled,
                caption: "Ready early on Monday: for each part of both meetings, what it's about and what it teaches about " \
                         "Jehovah, the Bible reading, ideas for Spiritual Gems comments and notes for the studies. AI writes " \
                         "it from this week's program on jw.org, in its own words. Only you see it.")
    f.submit(name: :submit, label: "Save", scheme: :primary) unless @disabled
  end
end
