import { Controller } from "@hotwired/stimulus"

// The "my time" dialog (docs/design/calendar.md, The "my time" dialog). What for fills in Title until Title is changed,
// and shows what the kind opens: the meeting prep line, or the select of the person's studies and notes.
export default class extends Controller {
  static targets = [ "title", "meetingPrep", "opens" ]
  static values = { titles: Object, openingKinds: Array }

  connect() {
    this.kind = this.element.querySelector("input[type=radio]:checked").value
  }

  kindChanged({ target: { value } }) {
    const previous = this.titlesValue[this.kind]
    this.kind = value

    if (this.titleTarget.value === "" || this.titleTarget.value === previous) this.titleTarget.value = this.titlesValue[value]
    this.meetingPrepTarget.hidden = value !== "meeting_prep"
    this.opensTarget.hidden = !this.openingKindsValue.includes(value)
  }
}
