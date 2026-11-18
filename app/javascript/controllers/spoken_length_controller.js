import { Controller } from "@hotwired/stimulus"

// The time line under a part's preparation (docs/design/meeting-parts.md, A part): counts the editor's words as the
// person types and rewrites the line, without asking the server. It counts and rounds exactly as
// MeetingPart::SpokenLength does: words at wordsPerMinute, rounded to 10 seconds, at least 10 for any words at all, and
// a list's bullet isn't a word. The line sits in the same form as the editor.
export default class extends Controller {
  static targets = [ "length", "within", "over", "overBy" ]
  static values = { minutes: Number, wordsPerMinute: Number }

  connect() {
    this.count()
  }

  // Any editor's change reaches here, so only the preparation's is counted. Until Lexxy has started, toString() has
  // nothing to read and the line stays as the server drew it.
  count(event) {
    const editor = this.element.closest("form").querySelector("lexxy-editor")
    if (event && event.target !== editor) return

    const text = editor.toString()
    if (text === undefined) return

    const seconds = this.#seconds(text)
    this.element.hidden = seconds === null
    if (seconds === null) return

    const over = seconds - this.minutesValue * 60
    this.lengthTarget.textContent = `About ${duration(seconds)} to say`
    this.withinTarget.hidden = over > 0
    this.overTarget.hidden = over <= 0
    this.overByTarget.textContent = over > 0 ? `${duration(over)} over your ${this.minutesValue} min` : ""
  }

  #seconds(text) {
    const words = text.split(/\s+/).filter(word => /[\p{L}\p{N}]/u.test(word)).length
    if (words === 0) return null

    return Math.max(Math.round(words * 60 / this.wordsPerMinuteValue / 10) * 10, 10)
  }
}

// "2 min 40 s", "1 min", "50 s", as MeetingPart::SpokenLength.duration
function duration(seconds) {
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  return [ minutes > 0 ? `${minutes} min` : null, rest > 0 ? `${rest} s` : null ].filter(Boolean).join(" ")
}
