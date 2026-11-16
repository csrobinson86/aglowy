# First use of AI drafts (frame ai-terms.png). "Not now" goes back to the panel's start without sending anything;
# not_now: false leaves it out where there's no panel to close (a personal study's ask box).
class AiAcceptances::AcceptanceForm < ApplicationForm
  def initialize(not_now: true)
    @not_now = not_now
  end

  form do |f|
    f.check_box(name: :understood, label: "I understand how AI drafts work", required: true)
    f.group(layout: :horizontal, mt: 3) do |actions|
      actions.submit(name: :submit, label: "Turn on AI drafts", scheme: :primary)
      actions.button(name: :not_now, label: "Not now", data: { action: "ai-panel#close" }) if @not_now
    end
  end
end
