import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Each draft stream's watch on its connected attribute, until the stream leaves the page.
const catchUpObservers = new WeakMap()

// Below Primer's md breakpoint the open panel shows in a full-screen dialog (docs/design/family-studies.md, The panel).
const narrow = window.matchMedia("(max-width: 767.98px)")

// Opens and closes the AI panel, and fills the prompt from a starter idea. Beside the form it opens in place; on a phone
// its content moves into the dialog, and a draft's actions into the dialog's footer. Accepting the terms and drafting
// are plain form posts inside the panel's Turbo Frame. While drafting, the panel listens on the draft's stream.
export default class extends Controller {
  static targets = [ "start", "opened", "prompt", "stream", "dialog", "dialogBody", "dialogFooter", "footer", "footerHome" ]

  connect() {
    narrow.addEventListener("change", this.place)
  }

  disconnect() {
    narrow.removeEventListener("change", this.place)
  }

  // Each answer replaces the panel, already open: on a phone it goes straight into the dialog, unless the person closed
  // the dialog since "Draft with AI". A draft that comes after Escape waits under the Start box, not over the form.
  openedTargetConnected() {
    if (this.dismissed && !this.openedTarget.hidden) {
      this.openedTarget.hidden = true
      this.startTarget.classList.remove("d-md-none")
    }
    this.place()
  }

  // Each answer replaces the panel's Turbo Frame, so whether the dialog was closed is kept on the element around it.
  get dismissed() {
    return this.element.parentElement.hasAttribute("data-ai-panel-dismissed")
  }

  set dismissed(value) {
    this.element.parentElement.toggleAttribute("data-ai-panel-dismissed", value)
  }

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
    this.dismissed = false
    this.startTarget.classList.add("d-md-none")
    this.openedTarget.hidden = false
    this.place()
    const field = this.openedTarget.querySelector("textarea:not([disabled]), input:not([type=hidden]):not([disabled])")
    ;(field || this.openedTarget.querySelector("button:not([disabled])"))?.focus()
  }

  close({ focus = true } = {}) {
    this.dismissed = narrow.matches
    this.openedTarget.hidden = true
    this.startTarget.classList.remove("d-md-none")
    this.place()
    if (focus) this.startTarget.querySelector("button")?.focus()
  }

  // Escape or the dialog's close button. Closing it here, or because the screen widened, has already been handled.
  dialogClosed({ target }) {
    if (target == this.dialogTarget && !this.openedTarget.hidden && narrow.matches) this.close()
  }

  // "Use this draft" filled the form: on a phone the dialog closes so the form shows (the ai-draft controller then
  // moves focus to it). Beside the form the panel stays, showing "Draft added".
  used() {
    if (this.dialogTarget.open) this.close({ focus: false })
  }

  // Into the dialog while the panel is open below md; otherwise back in place. Each move sets off the target callbacks
  // again, so only what isn't already where it belongs moves.
  place = () => {
    const inDialog = !this.openedTarget.hidden && narrow.matches
    const panelHome = inDialog ? this.dialogBodyTarget : this.startTarget.parentElement
    if (this.openedTarget.parentElement != panelHome) {
      if (inDialog) panelHome.append(this.openedTarget)
      else this.startTarget.after(this.openedTarget)
    }

    if (this.hasFooterTarget) {
      const footerHome = inDialog ? this.dialogFooterTarget : this.footerHomeTarget
      if (this.footerTarget.parentElement != footerHome) footerHome.append(this.footerTarget)
    }

    if (inDialog && !this.dialogTarget.open) this.dialogTarget.showModal()
    if (!inDialog && this.dialogTarget.open) this.dialogTarget.close()
  }

  // The input event lets Primer's character counter catch up.
  fill({ params: { text } }) {
    this.promptTarget.value = text
    this.promptTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.promptTarget.focus()
  }
}
