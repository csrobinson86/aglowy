import { Controller } from "@hotwired/stimulus"

// Notes editors take scripture links and nothing else, so a file dropped or pasted into one never starts
// uploading, whatever its type (docs/design/scripture-links.md, Editor options).
export default class extends Controller {
  refuse(event) {
    event.preventDefault()
  }
}
