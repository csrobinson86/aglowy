import { Controller } from "@hotwired/stimulus"

// On a Turbo Frame whose links load a dialog that a save closes by emptying the frame and refreshing the page, as a go
// bag's item dialog. The refresh draws a new page, so the browser has no opener to give focus back to and it falls to
// the body. Instead it goes to the link that opened the dialog, found again by its id; or, when that's gone, as for a
// removed item, the last link in its section (its "+ Add item"); or the first link on the page that opens the frame.
// Closing the dialog leaves focus to the browser, and leaving the page with the dialog open forgets it.
let returnTo = null

export default class extends Controller {
  connect() {
    if (returnTo?.frame !== this.element.id) return

    const { ids } = returnTo
    returnTo = null
    const target = ids.map(id => id && document.getElementById(id)).find(link => link?.checkVisibility()) ?? this.#openers(document)[0]
    target?.focus()
  }

  disconnect() {
    if (this.element.querySelector("dialog")) returnTo = null
  }

  // Bound on the document's clicks, which a link's Enter fires too.
  remember({ target }) {
    const opener = target.closest?.(`a[data-turbo-frame="${this.element.id}"]`)
    if (!opener) return

    const section = opener.closest("section")
    returnTo = { frame: this.element.id, ids: [ opener.id, section && this.#openers(section).at(-1)?.id ] }
  }

  // Bound with :capture, as close doesn't bubble. It also fires when a save's Turbo Stream takes the dialog off the page
  // open, with focus still to put back, and when Primer's dialog-helper closes and reopens it as a modal on opening.
  forget({ target: dialog }) {
    if (dialog.isConnected && !dialog.open) returnTo = null
  }

  #openers(root) {
    return [ ...root.querySelectorAll(`a[data-turbo-frame="${this.element.id}"]`) ]
  }
}
