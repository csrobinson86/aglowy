import { Controller } from "@hotwired/stimulus"

// Around dialogs whose openers a Turbo Stream can replace, as a goal's step panels (docs/design/phone.md, A goal, The
// step panel): a tick in a panel redraws its step's row, "›" and all, and Save or Remove redraws every row with the
// panel open. The browser gives focus back only to the opener it saw open the dialog, so once that's gone focus would
// fall to the body. Instead it goes to the dialog's opener on the page now: when the dialog closes, and when a Turbo
// Stream takes it off the page open. A removed step's panel has none left, so focus goes to the next step's opener,
// or the one before, or the fallback (the Steps heading) when no step is left.
export default class extends Controller {
  static values = { fallback: String }

  // Bound with :capture, as close doesn't bubble. The browser has already moved focus by then, or failed to. A panel
  // opened on a phone and closed at desktop width has its "›" hidden, so focus goes to the fallback.
  refocus({ target: dialog }) {
    if (document.activeElement === document.body || dialog.contains(document.activeElement)) {
      (this.#opener(dialog) ?? document.getElementById(this.fallbackValue))?.focus()
    }
  }

  disconnect() {
    const dialogs = [ ...this.element.querySelectorAll("dialog") ]
    const open = dialogs.findIndex(dialog => dialog.open)
    if (open === -1) return

    const nearest = [ ...dialogs.slice(open), ...dialogs.slice(0, open).reverse() ]
    const target = nearest.map(dialog => this.#opener(dialog)).find(Boolean) ?? document.getElementById(this.fallbackValue)
    target?.focus()
  }

  #opener(dialog) {
    return [ ...document.querySelectorAll(`[data-show-dialog-id="${dialog.id}"]`) ].find(opener => opener.checkVisibility())
  }
}
