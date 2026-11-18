import { Controller } from "@hotwired/stimulus"

// Around dialogs that a Turbo Stream takes off the page while open, as Your plan's saved focus area response empties
// the dialog's frame. A removed dialog never fires close, so Primer's dialog-helper leaves the body's has-modal classes
// on and the page can't scroll. Once they're gone, set the classes as Primer does: on while any dialog is still open.
export default class extends Controller {
  disconnect() {
    document.body.classList.toggle("has-modal", Boolean(document.querySelector("dialog[open]")))
    document.body.classList.toggle("has-modal-disable-scroll", Boolean(document.querySelector("dialog[open].Overlay--disableScroll")))
  }
}
