import { Controller } from "@hotwired/stimulus"

// From Primer's md breakpoint up.
const wide = matchMedia("(min-width: 768px)")

// What changes on a study page between a phone and md up (docs/design/personal-study.md, Pages and routes).
// - The one tag editor sits under the title from md up, and in the "…" menu's Tags dialog on a phone, so adding or
//   removing a tag replaces it in whichever place it is.
// - The menu's phone-only items are hidden from md up with the hidden attribute, which Primer's menu focus skips.
// - From md up the tabs are hidden and every panel shows, so the panels leave the tab order.
export default class extends Controller {
  static targets = [ "inline", "dialog", "phoneOnly", "panel" ]

  connect() {
    this.place = () => this.arrange()
    wide.addEventListener("change", this.place)
    this.arrange()
  }

  disconnect() {
    wide.removeEventListener("change", this.place)
  }

  arrange() {
    const editor = this.inlineTarget.firstElementChild ?? this.dialogTarget.firstElementChild
    const place = wide.matches ? this.inlineTarget : this.dialogTarget
    if (editor && editor.parentElement !== place) place.append(editor)

    for (const item of this.phoneOnlyTargets) item.hidden = wide.matches
    for (const panel of this.panelTargets) panel.tabIndex = wide.matches ? -1 : 0
  }
}
