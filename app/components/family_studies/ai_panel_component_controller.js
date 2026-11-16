import { Controller } from "@hotwired/stimulus"

// Opens and closes the AI panel in place, and fills the prompt from a starter idea. Nothing here talks to the
// server: accepting the terms and drafting are plain form posts inside the panel's Turbo Frame.
export default class extends Controller {
  static targets = [ "start", "opened", "prompt" ]

  open() {
    this.startTarget.hidden = true
    this.openedTarget.hidden = false
    const field = this.openedTarget.querySelector("textarea:not([disabled]), input:not([type=hidden]):not([disabled])")
    ;(field || this.openedTarget.querySelector("button:not([disabled])"))?.focus()
  }

  close() {
    this.openedTarget.hidden = true
    this.startTarget.hidden = false
    this.startTarget.querySelector("button")?.focus()
  }

  // The input event lets Primer's character counter catch up.
  fill({ params: { text } }) {
    this.promptTarget.value = text
    this.promptTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.promptTarget.focus()
  }
}
