import { Controller } from "@hotwired/stimulus"

// A note's Edit form (docs/design/notes.md, A note: the version check). The tag editor sits beside the form and saves
// each tag at once, so as "Save note" sends the form this copies the tags the editor shows into tag_names, only for
// "What you wrote" if the save is refused. The editor keeps its tags in its current value (TagEditorComponent).
export default class extends Controller {
  static targets = [ "field" ]
  static values = { editor: String }

  fill() {
    const editor = document.getElementById(this.editorValue)
    if (editor) this.fieldTarget.value = JSON.parse(editor.dataset.tagEditorCurrentValue).join(" ")
  }
}
