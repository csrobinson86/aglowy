import { Controller } from "@hotwired/stimulus"

// Each question stream's watch on its connected attribute, until the stream leaves the page.
const catchUpObservers = new WeakMap()

// A study page's ask box and the answers above it (docs/design/personal-study.md, The study page). "Keep digging"
// and "Ask it again" put a question in the box for the person to send. While a question is answered, its card listens
// on the question's stream for progress and the checked result, which the page's own card then replaces.
export default class extends Controller {
  static targets = [ "prompt", "stream", "unscoped" ]

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
    const observer = new MutationObserver(() => this.queueCatchUp(stream))
    observer.observe(stream, { attributes: true, attributeFilter: [ "connected" ] })
    catchUpObservers.set(stream, observer)
    this.queueCatchUp(stream)
  }

  streamTargetDisconnected(stream) {
    catchUpObservers.get(stream)?.disconnect()
    catchUpObservers.delete(stream)
  }

  // The job's checked result is rendered once for every page showing the question, in whichever household, so it
  // has no household for Save to note to post to. The page's own card has, so it takes the result's place.
  unscopedTargetConnected(element) {
    this.queue(() => this.replaceFromPage(element.closest(".study-question"), element))
  }

  // One at a time, so each look reads the page after the one before it was applied, and an older read never puts back
  // counts a newer one replaced. A failed look changes nothing; the stream's next reconnect looks again.
  queueCatchUp(stream) {
    this.queue(() => this.catchUp(stream))
  }

  queue(look) {
    this.catchingUp = (this.catchingUp ?? Promise.resolve()).then(look).catch(() => {})
  }

  // The study page as it is now: once the question has finished there, it replaces the card, and the study's counts
  // and sources come with it. Nothing changes while it's still asking, or once the stream has left the page.
  async catchUp(stream) {
    if (!stream.hasAttribute("connected")) return
    await this.replaceFromPage(stream.closest(".study-question"), stream)
  }

  // Nothing changes once +watched+ has left the page: a newer card is there already.
  async replaceFromPage(question, watched) {
    const response = await fetch(window.location.pathname, { headers: { Accept: "text/html" } })
    if (!response.ok) return

    const page = new DOMParser().parseFromString(await response.text(), "text/html")
    if (!watched.isConnected) return
    const finished = page.getElementById(question.id)
    // Still asking there, or a card without Save to note either, which would only look again.
    if (!finished || finished.querySelector("turbo-cable-stream-source, [data-study-ask-target~=unscoped]")) return

    for (const fresh of [ finished, ...page.querySelectorAll("[data-study-ask-catch-up]") ]) {
      document.getElementById(fresh.id)?.replaceWith(document.importNode(fresh, true))
    }
  }
}
