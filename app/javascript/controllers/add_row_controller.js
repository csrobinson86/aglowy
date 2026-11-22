import { Controller } from "@hotwired/stimulus"

// An add-row form behind its "+ Add <thing>" button on a phone (docs/design/phone.md, The rules: 7). Opening it hides
// the button and focuses the first field; Cancel clears and hides the form and puts focus back on the button. From md
// up the form always shows (add_row.scss) and the button doesn't.
export default class extends Controller {
  static targets = [ "button", "form" ]

  open() {
    this.buttonTarget.hidden = true
    this.formTarget.hidden = false
    this.formTarget.querySelector("input:not([type=hidden])").focus()
  }

  close() {
    this.formTarget.querySelector("form").reset()
    this.formTarget.hidden = true
    this.buttonTarget.hidden = false
    this.buttonTarget.focus()
  }
}
