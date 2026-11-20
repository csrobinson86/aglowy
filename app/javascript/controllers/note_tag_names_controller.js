import { Controller } from "@hotwired/stimulus"

// A note's form, on New note and Edit (docs/design/notes.md, A note: Tags on a new note). The tag editor sits beside
// the form, so as "Save note" sends it this copies the names the editor shows in, one hidden personal_note[tag_names][]
// field each, as typed and never split. New note saves them with the note; on Edit they're only for "What you wrote"
// if the save is refused. The editor keeps its names in its current value (TagEditorComponent).
export default class extends Controller {
  static targets = [ "field" ]
  static values = { editor: String }

  fill() {
    for (const field of this.fieldTargets) field.remove()
    const editor = document.getElementById(this.editorValue)
    if (!editor) return

    for (const name of JSON.parse(editor.dataset.tagEditorCurrentValue)) {
      const field = document.createElement("input")
      field.type = "hidden"
      field.name = "personal_note[tag_names][]"
      field.value = name
      field.dataset.noteTagNamesTarget = "field"
      this.element.append(field)
    }
  }
}
