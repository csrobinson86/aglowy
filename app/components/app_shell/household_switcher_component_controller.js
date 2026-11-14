import { Controller } from "@hotwired/stimulus"

// Primer ticks a clicked household straight away, and Turbo caches the page
// it leaves, so Back would show the other household ticked. Put the page's
// own household back before Turbo caches it.
export default class extends Controller {
  connect() {
    this.current = this.element.querySelector("[aria-checked='true']")
  }

  reset() {
    for (const item of this.element.querySelectorAll("[aria-checked]")) {
      item.setAttribute("aria-checked", item === this.current)
    }
  }
}
