import { Controller } from "@hotwired/stimulus"

// The tag editor (TagEditorComponent). Primer's AutoComplete fetches its suggestions from src; this answers from
// the person's own tags already in the page instead, filtered by what's typed, plus "Create "#name"" when the text
// isn't a tag they have (docs/design/tags.md, The tag editor). Choosing one adds it; Enter adds what was typed.
export default class extends Controller {
  static targets = [ "suggestions", "create" ]
  static values = { focus: Boolean, current: Array }

  connect() {
    this.autocomplete.fetchResult = async (url) => this.results(url.searchParams.get("q"))
    // After adding, the editor is replaced; focus goes back to the input for the next tag.
    if (this.focusValue) this.input.focus()
  }

  // AutoComplete sets the input to the chosen option's value, then this submits it.
  commit() {
    if (this.input.value) this.input.form.requestSubmit()
  }

  results(query) {
    const name = normalize(query)
    const list = document.createElement("div")
    // Tags already on it aren't suggested, and aren't offered to create.
    for (const option of this.suggestionsTarget.content.querySelectorAll("[role=option]")) {
      if (name && option.dataset.autocompleteValue.includes(name)) list.append(option.cloneNode(true))
    }
    const suggested = [ ...this.suggestionsTarget.content.querySelectorAll("[role=option]") ].map((option) => option.dataset.autocompleteValue)
    if (name && !suggested.includes(name) && !this.currentValue.includes(name)) list.append(this.createOption(name))
    return list.innerHTML
  }

  createOption(name) {
    const option = this.createTarget.content.querySelector("[role=option]").cloneNode(true)
    option.dataset.autocompleteValue = name
    option.querySelector(".ActionListItem-label").textContent = `Create "#${name}"`
    return option
  }

  get autocomplete() {
    return this.element.querySelector("auto-complete")
  }

  get input() {
    return this.autocomplete.querySelector("input")
  }
}

// The same as Tag.normalize: "Talk Prep" and "#talk_prep" are both talk-prep.
function normalize(text) {
  return text.trim().replace(/^#/, "").toLowerCase().replace(/[\s_]+/g, "-").replace(/[^a-z0-9-]/g, "").replace(/^-+/, "").slice(0, 30)
}
