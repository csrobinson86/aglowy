import { Controller } from "@hotwired/stimulus"

// The household event dialog (docs/design/calendar.md, The household event dialog). Kind fills in Title until Title is
// changed, and ticks All day for assemblies, conventions and the CO's visit. All day shows Starts and Ends dates, or a
// Date with Starts and Ends times; the hidden group's inputs are disabled, so they aren't sent. A new date redraws the
// Repeats frame on the server, whose choices come from the date, and an all-day event ending on a later day hides it.
export default class extends Controller {
  static targets = [ "kind", "title", "allDay", "allDayFields", "timedFields", "startsOn", "endsOn", "date", "repeat", "repeatField", "repeatFrame" ]
  static values = { titles: Object, allDayKinds: Array, url: String }

  connect() {
    this.kind = this.kindTarget.value
    this.startsOn = this.#startsOn
  }

  kindChanged() {
    const previous = this.titlesValue[this.kind]
    this.kind = this.kindTarget.value

    if (this.titleTarget.value === "" || this.titleTarget.value === previous) {
      this.titleTarget.value = this.titlesValue[this.kind]
      this.allDayTarget.checked = this.allDayKindsValue.includes(this.kind)
      this.allDayChanged()
    }
  }

  // The shown date input takes the hidden one's value, so the date carries over.
  allDayChanged() {
    const allDay = this.allDayTarget.checked
    const [ from, to ] = allDay ? [ this.dateTarget, this.startsOnTarget ] : [ this.startsOnTarget, this.dateTarget ]
    to.value = from.value

    this.#show(this.allDayFieldsTarget, allDay)
    this.#show(this.timedFieldsTarget, !allDay)
    this.dateChanged()
  }

  // A later first day moves Ends with it. Ends itself is left alone while it's typed.
  dateChanged() {
    const startsOn = this.#startsOn
    if (startsOn > this.endsOnTarget.value) this.endsOnTarget.value = startsOn

    this.endsChanged()
    if (startsOn === this.startsOn) return

    this.startsOn = startsOn
    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set("household_event[starts_on]", startsOn)
    url.searchParams.set("household_event[repeat]", this.repeatTarget.value)
    this.repeatFrameTarget.src = url.toString()
  }

  endsChanged() {
    this.repeatFieldTarget.hidden = this.allDayTarget.checked && this.endsOnTarget.value > this.#startsOn
  }

  get #startsOn() {
    return (this.allDayTarget.checked ? this.startsOnTarget : this.dateTarget).value
  }

  #show(group, shown) {
    group.hidden = !shown
    group.querySelectorAll("input").forEach(input => input.disabled = !shown)
  }
}
