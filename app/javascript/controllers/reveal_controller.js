import { Controller } from "@hotwired/stimulus"

// Something hidden on a phone behind a button that shows and hides it, like Notes' search box behind its search button
// (docs/design/phone.md, Notes). The button says whether it's open, and opening focuses the first field. The open class
// shows the content below md; from md up the stylesheet always shows it and hides the button.
export default class extends Controller {
  static targets = [ "button", "content" ]
  static classes = [ "open" ]

  toggle() {
    const open = this.buttonTarget.getAttribute("aria-expanded") !== "true"
    this.buttonTarget.setAttribute("aria-expanded", open.toString())
    this.contentTarget.classList.toggle(this.openClass, open)
    if (open) this.contentTarget.querySelector("input:not([type=hidden])").focus()
  }
}
