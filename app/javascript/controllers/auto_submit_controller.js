import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a field changes, like Members and roles' role selects, which have no Save button.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
