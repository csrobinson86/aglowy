import { Controller } from "@hotwired/stimulus"

// Print: the browser's own print dialog. What's left out of the page is in the print styles
// (components/_daily_brief.scss; docs/design/daily-brief.md, Keep in Notes, and print).
export default class extends Controller {
  print() {
    window.print()
  }
}
