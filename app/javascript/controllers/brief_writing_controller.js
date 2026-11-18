import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A daily brief's writing in progress, on its stream (docs/design/daily-brief.md, How a writing runs). The stream brings
// the progress lines and, once the writing has ended, a refresh of the page. Action Cable only delivers what's broadcast
// while the page is subscribed, and a quick ending (flagged, a provider error) can come before then, or while a dropped
// connection comes back. So each time it subscribes it asks: an ended writing answers with the refresh, one still
// being written with nothing.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.observer = new MutationObserver(() => this.catchUp())
    this.observer.observe(this.element, { attributes: true, attributeFilter: [ "connected" ] })
    this.catchUp()
  }

  disconnect() {
    this.observer.disconnect()
  }

  // An answer that comes once the stream has left the page is out of date.
  async catchUp() {
    if (!this.element.hasAttribute("connected")) return
    const response = await fetch(this.urlValue, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    if (response.status != 200) return
    const html = await response.text()
    if (this.element.isConnected) Turbo.renderStreamMessage(html)
  }
}
