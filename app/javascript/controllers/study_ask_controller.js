import { Controller } from "@hotwired/stimulus"

// Each question stream's watch on its connected attribute, until the stream leaves the page.
const catchUpObservers = new WeakMap()

// A study page's ask box and the answers above it (docs/design/personal-study.md, The study page). "Keep digging"
// and "Ask it again" put a question in the box for the person to send. While a question is answered, its card
// listens on the question's stream for progress and the checked result.
export default class extends Controller {
  static targets = [ "prompt", "stream" ]

  // The input event lets Primer's character counter catch up. A disabled box (the day's limit) stays empty.
  fill({ params: { text } }) {
    if (!this.hasPromptTarget || this.promptTarget.disabled) return
    this.promptTarget.value = text
    this.promptTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.promptTarget.focus()
  }

  // Action Cable only delivers what's broadcast while the card is subscribed, and a quick result (a flagged question,
  // a provider error) can come before it subscribes, or while a dropped connection comes back. Each time it
  // subscribes, look for the result; anything later arrives on the stream.
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

  // The study page as it is now: once the question has finished there, it replaces the card, and the study's counts
  // and sources come with it. Nothing changes while it's still asking, or once the stream has left the page.
  async catchUp(stream) {
    if (!stream.hasAttribute("connected")) return
    const question = stream.closest(".study-question")
    const response = await fetch(window.location.pathname, { headers: { Accept: "text/html" } })
    if (!response.ok || !stream.isConnected) return

    const page = new DOMParser().parseFromString(await response.text(), "text/html")
    const finished = page.getElementById(question.id)
    if (!finished || finished.querySelector("turbo-cable-stream-source")) return

    for (const fresh of [ finished, ...page.querySelectorAll("[data-study-ask-catch-up]") ]) {
      document.getElementById(fresh.id)?.replaceWith(document.importNode(fresh, true))
    }
  }
}
