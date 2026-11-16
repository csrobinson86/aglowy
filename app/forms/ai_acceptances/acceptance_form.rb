# First use of AI drafts (frame ai-terms.png). "Not now" goes back to the panel's start without sending anything.
class AiAcceptances::AcceptanceForm < ApplicationForm
  form do |f|
    f.check_box(name: :understood, label: "I understand how AI drafts work", required: true)
    f.group(layout: :horizontal, mt: 3) do |actions|
      actions.submit(name: :submit, label: "Turn on AI drafts", scheme: :primary)
      actions.button(name: :not_now, label: "Not now", data: { action: "ai-panel#close" })
    end
  end
end
