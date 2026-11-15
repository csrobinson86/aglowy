import { Controller } from "@hotwired/stimulus"

// "Copy link" beside the read-only password link (frame child-login-link.png). Primer's ClipboardCopyButton
// shows only an icon in 0.53.5, so this keeps a labelled Primer button. If the browser refuses the clipboard,
// the link is selected so it can be copied by hand.
export default class extends Controller {
  static targets = [ "source", "status" ]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.statusTarget.textContent = "Link copied."
    } catch {
      this.sourceTarget.select()
      this.statusTarget.textContent = "The link is selected. Copy it from there."
    }
  }
}
