# The "Pin" / "Pinned" toggle in a note's header (frame note.png), and the Unpin button on a pinned card (frame
# notes.png). The card's button says it's from the list, so the list refreshes itself after.
class PersonalNotes::PinForm < ApplicationForm
  def initialize(pinned:, card: false)
    @pinned = pinned
    @card = card
  end

  form do |f|
    if @card
      # The forms DSL takes size: as the field's size and drops it, so the small button is Primer's own modifier class.
      f.submit(name: :from, value: "list", label: "Unpin", scheme: :invisible, aria: { pressed: "true" }, classes: "Button--small") do |button|
        button.with_leading_visual_icon(icon: :pin)
      end
    else
      f.submit(name: :pin, label: @pinned ? "Pinned" : "Pin", aria: { pressed: @pinned.to_s }) do |button|
        button.with_leading_visual_icon(icon: :pin)
      end
    end
  end
end
