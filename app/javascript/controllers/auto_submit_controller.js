import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a field changes, like Members and roles' role selects, which have no Save button. With
// now, as soon as it's on the page: "Write it with AI" once the person has turned on AI drafts from the brief.
export default class extends Controller {
  static values = { now: Boolean }

  connect() {
    if (this.nowValue) this.submit()
  }

  submit() {
    this.element.requestSubmit()
  }
}
