import { Controller } from "@hotwired/stimulus"

// From Primer's md breakpoint up.
const wide = matchMedia("(min-width: 768px)")

// A page whose one tag editor sits under its title from md up, and in the "…" menu's Tags dialog on a phone
// (docs/design/phone.md, The rules: 5), so adding or removing a tag replaces it in whichever place it is. A page with
// no Tags dialog for this person (someone else's goal, a family goal) is left as it is.
export default class extends Controller {
  static targets = [ "inline", "dialog" ]

  connect() {
    this.place = () => this.arrange()
    wide.addEventListener("change", this.place)
    this.arrange()
  }

  disconnect() {
    wide.removeEventListener("change", this.place)
  }

  arrange() {
    if (!this.hasDialogTarget) return

    const editor = this.inlineTarget.firstElementChild ?? this.dialogTarget.firstElementChild
    const place = wide.matches ? this.inlineTarget : this.dialogTarget
    if (editor && editor.parentElement !== place) place.append(editor)
  }
}
