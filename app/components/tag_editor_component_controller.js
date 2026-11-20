import { Controller } from "@hotwired/stimulus"

// The tag editor (TagEditorComponent). Primer's AutoComplete fetches its suggestions from src; this answers from
// the person's own tags already in the page instead, filtered by what's typed, plus "Create "#name"" when the text
// isn't a tag they have (docs/design/tags.md, The tag editor). Choosing one adds it; Enter adds what was typed. On a
// note that isn't saved yet, adding and removing change only the page and the current value, which the note's form
// sends with it (docs/design/tags.md, The tag editor, on a note that isn't saved yet).
export default class extends Controller {
  static targets = [ "suggestions", "create", "tag", "template" ]
  static values = { focus: Boolean, current: Array }

  connect() {
    this.autocomplete.fetchResult = async (url) => this.results(url.searchParams.get("q"))
    // After adding or removing, the editor is replaced; focus goes back to the input for the next tag.
    if (this.focusValue) this.input.focus()
  }

  // AutoComplete sets the input to the chosen option's value, then this submits it. It also says so when typing clears
  // that value, which isn't a choice.
  commit() {
    if (this.autocomplete.value) this.input.form.requestSubmit()
  }

  // Unsaved only, as the add form's submit: the name, as typed, joins the page unless one the same once normalized is
  // already there. Nothing is sent.
  add(event) {
    event.preventDefault()
    const name = this.input.value.trim()
    if (name && !this.currentNames.includes(normalize(name))) {
      this.currentValue = [ ...this.currentValue, name ]
      this.input.form.before(this.tagFor(name))
    }
    this.input.value = ""
    // The editor stays, so the chosen value goes too: choosing the same name again, after removing it, still adds it.
    this.autocomplete.removeAttribute("value")
    this.autocomplete.open = false
    this.input.focus()
  }

  // Unsaved only: the remove button takes its tag off the page. Tags are in the same order as the current value.
  remove({ currentTarget }) {
    const index = this.tagTargets.findIndex((tag) => tag.contains(currentTarget))
    this.currentValue = this.currentValue.filter((_, position) => position !== index)
    this.tagTargets[index].remove()
    this.input.focus()
  }

  results(query) {
    const name = normalize(query)
    const current = this.currentNames
    const list = document.createElement("div")
    // Tags already on it aren't suggested, and aren't offered to create.
    for (const option of this.suggestionsTarget.content.querySelectorAll("[role=option]")) {
      const value = option.dataset.autocompleteValue
      if (name && value.includes(name) && !current.includes(value)) list.append(option.cloneNode(true))
    }
    const suggested = [ ...this.suggestionsTarget.content.querySelectorAll("[role=option]") ].map((option) => option.dataset.autocompleteValue)
    if (name && !suggested.includes(name) && !current.includes(name)) list.append(this.createOption(name))
    return list.innerHTML
  }

  // A blank plain Label and remove button from the template, named. The button's id goes, so clones don't share it.
  tagFor(name) {
    const tag = this.templateTarget.content.firstElementChild.cloneNode(true)
    tag.querySelector(".Label").textContent = `#${name}`
    const button = tag.querySelector("button")
    button.removeAttribute("id")
    button.setAttribute("aria-label", `Remove tag ${name}`)
    return tag
  }

  createOption(name) {
    const option = this.createTarget.content.querySelector("[role=option]").cloneNode(true)
    option.dataset.autocompleteValue = name
    option.querySelector(".ActionListItem-label").textContent = `Create "#${name}"`
    return option
  }

  // As tags are named: the current value holds names as typed on an unsaved note.
  get currentNames() {
    return this.currentValue.map(normalize)
  }

  get autocomplete() {
    return this.element.querySelector("auto-complete")
  }

  get input() {
    return this.autocomplete.querySelector("input")
  }
}

// The same as Tag.normalize: "Talk Prep" and "#talk_prep" are both talk-prep. Ruby's strip and \s mean only ASCII
// whitespace (strip takes null too), where JavaScript's trim and \s include a nonbreaking space, so they're spelled out.
function normalize(text) {
  return text.replace(/^[\0\t\n\v\f\r ]+|[\0\t\n\v\f\r ]+$/g, "").replace(/^#/, "").toLowerCase().replace(/[\t\n\v\f\r _]+/g, "-").replace(/[^a-z0-9-]/g, "").replace(/^-+/, "").slice(0, 30)
}
