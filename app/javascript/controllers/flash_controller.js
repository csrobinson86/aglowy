import { Controller } from "@hotwired/stimulus"

// Primer's Flash renders a close button but leaves dismissing it to the app.
export default class extends Controller {
  dismiss(event) {
    if (event.target.closest(".js-flash-close")) this.element.remove()
  }
}
