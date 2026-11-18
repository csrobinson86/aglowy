import { Controller } from "@hotwired/stimulus"

// The color picker (ColorPickerComponent): the chosen color's name beside the swatches follows the radios. Inside a
// note card, the card takes the chosen color at once, before "Save note" saves it (docs/design/notes.md, Colors), and
// its "Yellow note" for screen readers follows, gone for None as on a saved note (personal_notes/_color_name).
// The radios' values come from the list of colors, so the class is too. An avatar's picker is in no note card.
export default class extends Controller {
  static targets = [ "chosen" ]

  choose({ target, params: { name } }) {
    this.chosenTarget.textContent = name
    this.#recolorNoteCard(target.value, name)
  }

  #recolorNoteCard(color, name) {
    const card = this.element.closest(".note-card")
    if (!card) return

    card.classList.remove(...[ ...card.classList ].filter(name => name.startsWith("note-card--")))
    card.classList.add(`note-card--${color}`)
    this.#renameNoteCard(card, color, name)
  }

  #renameNoteCard(card, color, name) {
    let colorName = card.querySelector("[data-note-color-name]")
    if (color === "none") return colorName?.remove()

    if (!colorName) {
      colorName = document.createElement("span")
      colorName.className = "sr-only"
      colorName.dataset.noteColorName = ""
      card.prepend(colorName)
    }
    colorName.textContent = `${name} note`
  }
}
