import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Opens and closes the AI panel in place, and fills the prompt from a starter idea. Accepting the terms and drafting
// are plain form posts inside the panel's Turbo Frame. While drafting, the panel listens on the draft's stream.
export default class extends Controller {
  static targets = [ "start", "opened", "prompt", "stream" ]

  // Action Cable only delivers what's broadcast after the panel subscribes, and a quick result (a flagged request,
  // a provider error) can come before. Once subscribed, ask for the result once; anything later arrives on the stream.
  streamTargetConnected(stream) {
    const catchUp = () => {
      if (!stream.hasAttribute("connected")) return
      observer.disconnect()
      this.catchUp(stream.dataset.aiPanelUrlParam)
    }
    const observer = new MutationObserver(catchUp)
    observer.observe(stream, { attributes: true, attributeFilter: [ "connected" ] })
    catchUp()
  }

  async catchUp(url) {
    const response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    if (response.status == 200) Turbo.renderStreamMessage(await response.text())
  }

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
