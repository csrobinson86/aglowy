# The ask box under a study's conversation (frame personal-study.png). disabled: true is the day's limit, or a child
# without AI for personal study; the caption then says why.
class PersonalStudies::QuestionForm < ApplicationForm
  def initialize(label:, caption:, disabled: false)
    @label = label
    @caption = caption
    @disabled = disabled
  end

  form do |f|
    f.text_area(name: :prompt, label: @label, caption: @caption, required: true, character_limit: 1_000, rows: 3, full_width: true,
                disabled: @disabled, data: { study_ask_target: "prompt" })
    f.submit(name: :submit, label: "Ask", scheme: :primary, disabled: @disabled)
  end
end
