import { Controller } from "@hotwired/stimulus"

// Tapping a link in the phone menu leaves the dialog open while Turbo caches
// the page, so Back would reopen it. Close it before Turbo caches the page.
export default class extends Controller {
  close() {
    this.element.close()
  }
}
