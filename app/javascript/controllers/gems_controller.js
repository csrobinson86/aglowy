import { Controller } from "@hotwired/stimulus"

// "Add a gem" and remove under a Life and Ministry note's Spiritual Gems, the same pattern as the
// living-parts controller. A new gem is cloned from the <template> with a fresh fields_for index and
// fresh Primer UUIDs, so its inputs, labels and validation messages have ids no other gem has.
// Removing a saved gem marks it _destroy; a new one just leaves the page. Each remove button's label
// names the gem's reference, kept in step as the person types it.
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g

export default class extends Controller {
  static targets = [ "list", "template", "gem", "scripture", "destroy", "remove", "add" ]
  static values = { nextNumber: Number }

  add() {
    const fresh = new Map()
    const html = this.templateTarget.innerHTML
      .replaceAll("NEW_GEM", `${Date.now()}${this.nextNumberValue}`)
      .replaceAll("GEM_NUMBER", this.nextNumberValue)
      .replace(UUID, uuid => fresh.get(uuid) ?? fresh.set(uuid, crypto.randomUUID()).get(uuid))
    this.nextNumberValue++
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.scriptureTargets.at(-1).focus()
  }

  name(event) {
    const button = this.#within(event.target.closest("[data-gems-target='gem']"), this.removeTargets)
    const reference = event.target.value.trim()
    button.setAttribute("aria-label", reference ? `Remove ${reference}` : button.dataset.fallbackLabel)
  }

  remove(event) {
    const gem = event.target.closest("[data-gems-target='gem']")
    if (gem.dataset.newRecord === "true") {
      gem.remove()
    } else {
      this.#within(gem, this.destroyTargets).value = "1"
      gem.hidden = true
    }
    this.addTarget.focus()
  }

  #within(gem, targets) {
    return targets.find(target => gem.contains(target))
  }
}
