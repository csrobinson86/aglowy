import { Controller } from "@hotwired/stimulus"

// "Add another part" and remove on a Life and Ministry note's Living as Christians section. A new
// part is cloned from the <template> with a fresh fields_for index, so its inputs and its notes
// editor get ids no other part has. Removing a saved part marks it _destroy; the server only lets
// Living as Christians parts go (MeetingNote#only_repeating_parts_removed).
// Primer gives its labels and validation messages ids built from a UUID made once at render time,
// so each clone gets fresh UUIDs too, or every added part would point at the first one's.
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g

export default class extends Controller {
  static targets = [ "list", "template", "part", "title", "destroy", "add" ]
  static values = { nextNumber: Number }

  add() {
    const fresh = new Map()
    const html = this.templateTarget.innerHTML
      .replaceAll("NEW_PART", `${Date.now()}${this.nextNumberValue}`)
      .replaceAll("PART_NUMBER", this.nextNumberValue)
      .replace(UUID, uuid => fresh.get(uuid) ?? fresh.set(uuid, crypto.randomUUID()).get(uuid))
    this.nextNumberValue++
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.titleTargets.at(-1).focus()
  }

  remove(event) {
    const part = event.target.closest("[data-living-parts-target='part']")
    if (part.dataset.newRecord === "true") {
      part.remove()
    } else {
      this.destroyTargets.find(input => part.contains(input)).value = "1"
      part.hidden = true
    }
    this.addTarget.focus()
  }
}
