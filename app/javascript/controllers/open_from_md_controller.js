import { Controller } from "@hotwired/stimulus"

// From Primer's md breakpoint up.
const wide = matchMedia("(min-width: 768px)")

// A <details> that's always open from md up, where its summary is hidden, and starts closed on a phone (the
// Personal study list's "Collections and tags").
export default class extends Controller {
  connect() {
    this.open = () => this.openWhenWide()
    wide.addEventListener("change", this.open)
    this.openWhenWide()
  }

  disconnect() {
    wide.removeEventListener("change", this.open)
  }

  // The summary says it's open too, for when the screen narrows again.
  openWhenWide() {
    if (!wide.matches) return
    this.element.open = true
    this.element.querySelector("summary").setAttribute("aria-expanded", "true")
  }
}
