import { Controller } from "@hotwired/stimulus"

// Print: the browser's own print dialog. What's left out of the page is in the print styles
// (components/_daily_brief.scss; docs/design/daily-brief.md, Keep in Notes, and print). Paper is white, so the page
// prints in light colours whatever the person's appearance, and goes back to it afterwards.
export default class extends Controller {
  print() {
    window.print()
  }

  lighten() {
    this.colorMode = document.body.dataset.colorMode
    document.body.dataset.colorMode = "light"
  }

  restore() {
    if (this.colorMode) document.body.dataset.colorMode = this.colorMode
    this.colorMode = null
  }
}
