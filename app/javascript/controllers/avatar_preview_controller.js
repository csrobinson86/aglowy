import { Controller } from "@hotwired/stimulus"

// The avatar preview dialog (docs/design/avatars.md, The preview dialog). Upload photo opens the file input; choosing
// a file shows it at 160px in a circle, cropped to its middle square with object-fit: cover as the server will, from a
// local object URL. Nothing is uploaded until Save avatar submits the form. Over the size limit the error shows at once
// and Save is disabled; a photo the browser can't draw (HEIC on most desktops) gets a line instead, and still saves.
export default class extends Controller {
  static targets = [ "input", "dialog", "image", "unavailable", "name", "size", "error", "save" ]
  static values = { maxSize: Number }

  #url = null

  disconnect() {
    this.#revoke()
  }

  choose() {
    this.inputTarget.click()
  }

  preview() {
    const file = this.inputTarget.files[0]
    if (!file) return

    const tooBig = file.size > this.maxSizeValue
    this.nameTarget.textContent = file.name
    this.sizeTarget.textContent = this.#humanSize(file.size)
    this.errorTarget.hidden = !tooBig
    this.saveTarget.disabled = tooBig
    this.unavailableTarget.hidden = true
    this.imageTarget.hidden = tooBig

    this.#revoke()
    if (!tooBig) {
      this.#url = URL.createObjectURL(file)
      this.imageTarget.src = this.#url
    }
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  unavailable() {
    if (!this.imageTarget.getAttribute("src")) return

    this.imageTarget.hidden = true
    this.unavailableTarget.hidden = this.saveTarget.disabled
  }

  // Cancel or Escape: forget the file, so choosing the same one again opens the preview again.
  closed() {
    if (this.dialogTarget.returnValue === "submit") return

    this.inputTarget.value = ""
    this.#revoke()
  }

  #revoke() {
    if (this.#url) URL.revokeObjectURL(this.#url)
    this.#url = null
    this.imageTarget.removeAttribute("src")
  }

  #humanSize(bytes) {
    return bytes < 1024 * 1024 ? `${Math.max(1, Math.round(bytes / 1024))} KB` : `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }
}
