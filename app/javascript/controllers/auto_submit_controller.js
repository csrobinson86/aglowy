import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a field changes, like Members and roles' role selects, which have no Save button. With
// now, as soon as it's on the page: "Write it with AI" once the person has turned on AI drafts from the brief. With
// hold, the field that changed stays disabled until the response redraws it, as a go bag row's "we have it" box: its
// form posts or deletes as it was drawn, so a second change before the redraw would send the first one again. It's
// back on if the submission fails (release, on turbo:submit-end).
export default class extends Controller {
  static values = { now: Boolean, hold: Boolean }

  connect() {
    if (this.nowValue) this.submit()
  }

  submit(event) {
    this.element.requestSubmit()
    if (this.holdValue && event) {
      this.held = event.target
      this.held.disabled = true
    }
  }

  release({ detail: { success } }) {
    if (!success && this.held) this.held.disabled = false
  }
}
