import { Controller } from "@hotwired/stimulus"

// The color picker (ColorPickerComponent): the chosen color's name beside the swatches follows the radios.
export default class extends Controller {
  static targets = [ "chosen" ]

  choose({ params: { name } }) {
    this.chosenTarget.textContent = name
  }
}
