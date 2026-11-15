import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a field changes, like household settings' role selects, which have no Save button.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
