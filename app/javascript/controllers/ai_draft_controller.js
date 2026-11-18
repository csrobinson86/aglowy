import { Controller } from "@hotwired/stimulus"

// "Use this draft" copies the checked draft from the AI panel into the Schedule form, without asking the server
// (docs/design/family-studies.md, Use this draft): its title into Topic, its notes into the editor and its pages into
// Resources, as hidden link_urls[]. Nothing is saved until "Schedule study", and nothing records that AI was used.
// It sits on the element around both the form and the panel; the panel's targets come and go as its state changes.
// A meeting part's "Use this outline" uses it too, with no topic or resources: only the notes, which are its preparation
// (docs/design/meeting-parts.md, How a request runs).
export default class extends Controller {
  static targets = [ "topic", "topicHeading", "notesHeading", "notes", "label", "title", "template", "source", "review", "added", "topicDialog", "typedTopic" ]
  static outlets = [ "resource-links" ]

  #addedNotes = null

  // A topic the person already typed is theirs to keep, so ask first.
  use() {
    if (!this.hasTopicTarget) {
      this.#fill({ replaceTopic: false })
    } else if (this.topicTarget.value.trim() === "") {
      this.#fill({ replaceTopic: true })
    } else {
      this.typedTopicTarget.textContent = this.topicTarget.value
      this.topicDialogTarget.showModal()
    }
  }

  replaceTopic() {
    this.topicDialogTarget.close()
    this.#fill({ replaceTopic: true })
  }

  keepTopic() {
    this.topicDialogTarget.close()
    this.#fill({ replaceTopic: false })
  }

  // "From an AI draft" stays until the person changes Notes, not when the draft goes in.
  notesEdited() {
    if (this.hasLabelTarget && this.notesTarget.value !== this.#addedNotes) this.labelTarget.hidden = true
  }

  #fill({ replaceTopic }) {
    if (replaceTopic) this.topicTarget.value = this.titleTarget.textContent.trim()
    this.#addNotes(this.templateTarget.innerHTML)
    if (this.hasResourceLinksOutlet) this.sourceTargets.forEach(link => this.resourceLinksOutlet.append(link.href))

    this.reviewTargets.forEach(review => review.hidden = true)
    this.addedTarget.hidden = false
    // On a phone the AI panel closes its dialog for this, so the filled form shows.
    this.dispatch("used", { target: this.addedTarget })
    // "Use this draft" has gone, so focus moves to what replaced it, or on a phone to the top of the filled form.
    if (this.addedTarget.checkVisibility()) this.addedTarget.querySelector("h2").focus()
    else (this.hasTopicHeadingTarget ? this.topicHeadingTarget : this.notesHeadingTarget).focus()
  }

  // After what's there, if Notes isn't empty. Lexxy checks the HTML again as it takes it in.
  #addNotes(html) {
    const editor = this.notesTarget
    editor.value = editor.isEmpty ? html : editor.value + html
    this.#addedNotes = editor.value
    this.labelTarget.hidden = false
  }
}
