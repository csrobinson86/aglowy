import { Controller } from "@hotwired/stimulus"

// From Primer's md breakpoint up.
const wide = matchMedia("(min-width: 768px)")

// A study's tag editor sits under its title from md up, and in the "…" menu's Tags dialog on a phone (frame
// phone-personal-study.png). There's only one, so adding or removing a tag replaces it in whichever place it is.
export default class extends Controller {
  static targets = [ "inline", "dialog" ]

  connect() {
    this.place = () => this.move()
    wide.addEventListener("change", this.place)
    this.move()
  }

  disconnect() {
    wide.removeEventListener("change", this.place)
  }

  move() {
    const editor = this.inlineTarget.firstElementChild ?? this.dialogTarget.firstElementChild
    const place = wide.matches ? this.inlineTarget : this.dialogTarget
    if (editor && editor.parentElement !== place) place.append(editor)
  }
}
