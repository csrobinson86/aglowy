import { Controller } from "@hotwired/stimulus"

// The color picker (ColorPickerComponent): the chosen color's name beside the swatches follows the radios. Inside a
// note card, the card takes the chosen color at once, before "Save note" saves it (docs/design/notes.md, Colors).
// The radios' values come from the list of colors, so the class is too. An avatar's picker is in no note card.
export default class extends Controller {
  static targets = [ "chosen" ]

  choose({ target, params: { name } }) {
    this.chosenTarget.textContent = name
    this.#recolorNoteCard(target.value)
  }

  #recolorNoteCard(color) {
    const card = this.element.closest(".note-card")
    if (!card) return

    card.classList.remove(...[ ...card.classList ].filter(name => name.startsWith("note-card--")))
    card.classList.add(`note-card--${color}`)
  }
}
