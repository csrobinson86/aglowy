import { Controller } from "@hotwired/stimulus"

// Reloads the Repeat field's Turbo Frame for the new date. The choices and their
// labels come from the server (FamilyStudy::Scheduling#repeat_choices), never from here.
export default class extends Controller {
  static targets = [ "date", "repeat", "frame" ]
  static values = { url: String }

  refresh() {
    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set("family_study_scheduling[starts_on]", this.dateTarget.value)
    url.searchParams.set("family_study_scheduling[repeat]", this.repeatTarget.value)
    this.frameTarget.src = url.toString()
  }

  // The request carried the Repeat choice from when the date changed; keep one made since,
  // if the new date still offers it.
  keepRepeat({ detail: { newFrame } }) {
    const choice = this.repeatTarget.value
    const options = [ ...newFrame.querySelector("select").options ]

    if (options.some(option => option.value === choice)) {
      options.forEach(option => option.toggleAttribute("selected", option.value === choice))
    }
  }
}
