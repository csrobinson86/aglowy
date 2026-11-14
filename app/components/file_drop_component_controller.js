import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

// The file drop zone (FileDropComponent). Uploads each dropped or chosen file straight to storage,
// with its own progress bar, or the server's reason when it refuses one before any bytes go up.
// Each uploaded file becomes a hidden signed blob id in the surrounding form.
export default class extends Controller {
  static targets = ["input", "list", "template", "submit"]
  static values = { url: String, name: String, submitWhenUploaded: Boolean }

  connect() {
    this.uploading = 0
    this.refused = false
    this.form = this.element.closest("form")
    this.holdSubmit = this.holdSubmit.bind(this)
    this.form.addEventListener("submit", this.holdSubmit)
  }

  disconnect() {
    this.form.removeEventListener("submit", this.holdSubmit)
  }

  choose() {
    this.upload(this.inputTarget.files)
    this.inputTarget.value = ""
  }

  dragOver(event) {
    event.preventDefault()
    this.element.classList.add("file-drop--active")
  }

  dragLeave() {
    this.element.classList.remove("file-drop--active")
  }

  drop(event) {
    event.preventDefault()
    this.dragLeave()
    this.upload(event.dataTransfer.files)
  }

  upload(files) {
    Array.from(files).forEach(file => this.uploadFile(file))
  }

  uploadFile(file) {
    const item = this.templateTarget.content.firstElementChild.cloneNode(true)
    const part = name => item.querySelector(`[data-file-drop-part="${name}"]`)
    part("name").textContent = file.name
    part("progress").setAttribute("aria-label", `Uploading ${file.name}`)
    this.listTarget.append(item)
    this.uploading++

    let blobRequest
    const upload = new DirectUpload(file, this.urlValue, {
      directUploadWillCreateBlobWithXHR: xhr => { blobRequest = xhr },
      directUploadWillStoreFileWithXHR: xhr => {
        xhr.upload.addEventListener("progress", ({ loaded, total }) => { part("progress").value = loaded / total * 100 })
      }
    })

    upload.create((error, blob) => {
      if (error) {
        this.refused = true
        part("progress").remove()
        part("error").textContent = blobRequest?.response?.error || "Couldn't be uploaded. Try again."
        part("error").hidden = false
      } else {
        part("progress").value = 100
        part("progress").setAttribute("aria-label", `Uploaded ${file.name}`)
        item.append(this.signedIdInput(blob.signed_id))
      }
      this.uploading--
      if (this.uploading === 0) this.uploaded()
    })
  }

  // A form sent mid-upload would leave files behind, so it waits and goes once they're up.
  holdSubmit(event) {
    if (this.uploading > 0) {
      event.preventDefault()
      this.submitWhenDone = true
    }
  }

  uploaded() {
    const anyUploaded = this.listTarget.querySelector(`input[name="${this.nameValue}"]`)

    if (this.submitWhenDone || (this.submitWhenUploadedValue && anyUploaded && !this.refused)) {
      this.form.requestSubmit()
    } else if (this.hasSubmitTarget && anyUploaded) {
      this.submitTarget.hidden = false
    }
  }

  signedIdInput(signedId) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = this.nameValue
    input.value = signedId
    return input
  }
}
