import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Each draft stream's watch on its connected attribute, until the stream leaves the page.
const catchUpObservers = new WeakMap()

// Opens and closes the AI panel in place, and fills the prompt from a starter idea. Accepting the terms and drafting
// are plain form posts inside the panel's Turbo Frame. While drafting, the panel listens on the draft's stream.
export default class extends Controller {
  static targets = [ "start", "opened", "prompt", "stream" ]

  // Action Cable only delivers what's broadcast while the panel is subscribed, and a quick result (a flagged request,
  // a provider error) can come before it subscribes, or while a dropped connection comes back. Each time it
  // subscribes, ask for the result; anything later arrives on the stream.
  streamTargetConnected(stream) {
    const observer = new MutationObserver(() => this.catchUp(stream))
    observer.observe(stream, { attributes: true, attributeFilter: [ "connected" ] })
    catchUpObservers.set(stream, observer)
    this.catchUp(stream)
  }

  streamTargetDisconnected(stream) {
    catchUpObservers.get(stream)?.disconnect()
    catchUpObservers.delete(stream)
  }

  // An answer that comes once the stream has left the page is out of date: the result came on the stream, and the
  // person may have discarded it or asked again since.
  async catchUp(stream) {
    if (!stream.hasAttribute("connected")) return
    const response = await fetch(stream.dataset.aiPanelUrlParam, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    if (response.status != 200) return
    const html = await response.text()
    if (stream.isConnected) Turbo.renderStreamMessage(html)
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
