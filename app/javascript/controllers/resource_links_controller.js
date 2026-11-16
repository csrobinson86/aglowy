import { Controller } from "@hotwired/stimulus"

// "Add a link" on the Schedule a study form: moves the URL into the list as a hidden input,
// so the links are sent with the study. The server checks every link again (FamilyStudy::Scheduling).
export default class extends Controller {
  static targets = [ "input", "list", "template", "blank" ]

  add(event) {
    event.preventDefault()
    const typed = this.inputTarget.value.trim()
    if (typed === "") return

    const url = this.#webLink(typed)
    if (!url) {
      this.inputTarget.setCustomValidity("Link must be a web address starting with http:// or https://")
      this.inputTarget.reportValidity()
      return
    }

    this.append(url)
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }

  // A link into the list, from "Add link" or an AI draft's pages (the ai-draft controller). Once only: nothing else
  // stops a study saving the same link twice.
  append(url) {
    if ([ ...this.listTarget.querySelectorAll("input") ].some(input => input.value === url)) return

    const item = this.templateTarget.content.firstElementChild.cloneNode(true)
    item.querySelector("[data-link-text]").textContent = url
    item.querySelector("input").value = url
    this.listTarget.append(item)
    this.blankTarget.hidden = true
  }

  resetValidity() {
    this.inputTarget.setCustomValidity("")
  }

  // Like FamilyStudy::Resource#web_link?: the parsed scheme, never the start of the string (gotcha 23).
  // Returns the browser's normalized form ("http:host" becomes "http://host/"), so the list holds what the server judges.
  #webLink(typed) {
    try {
      const url = new URL(typed)
      return [ "http:", "https:" ].includes(url.protocol) && url.host !== "" ? url.href : null
    } catch {
      return null
    }
  }
}
