import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The meeting helper's drawing page (docs/design/meeting-helper.md, Drawing). Strokes are kept in a fixed
// 1116×470 logical space, scaled by devicePixelRatio, so Undo can redraw without the last one. A saved drawing
// (imageUrl, the authorizing drawing route) is the paper's first layer, so drawing again adds to it.
const WIDTH = 1116
const HEIGHT = 470
const LINE_WIDTH = 9

export default class extends Controller {
  static targets = [ "canvas", "swatch", "form", "input", "done" ]
  static values = { imageUrl: String, stepUrl: String }

  connect() {
    this.strokes = []
    this.picture = null
    this.changed = false
    this.loading = Promise.resolve()
    this.colour = this.colourOf(this.swatchTargets.find(swatch => swatch.getAttribute("aria-pressed") === "true"))

    const ratio = window.devicePixelRatio || 1
    this.canvasTarget.width = WIDTH * ratio
    this.canvasTarget.height = HEIGHT * ratio
    this.paper = this.canvasTarget.getContext("2d")
    this.paper.scale(ratio, ratio)
    this.paper.lineCap = "round"
    this.paper.lineJoin = "round"
    this.paper.lineWidth = LINE_WIDTH
    this.redraw()

    if (this.hasImageUrlValue) this.load()
  }

  // Production storage is another host; asking for it with CORS keeps the canvas exportable. If the saved picture
  // can't load, All done keeps it rather than saving over it without it. Start over replaces this.loading, so a
  // picture that arrives after it stays off the paper, and abandons the wait, so an All done waiting on it goes on.
  load() {
    const picture = new Image()
    picture.crossOrigin = "anonymous"
    const loading = this.loading = new Promise(resolve => {
      this.abandon = () => resolve(false)
      picture.onload = () => resolve(true)
      picture.onerror = () => resolve(false)
    })
    loading.then(loaded => {
      if (this.loading !== loading) return

      if (loaded) {
        this.picture = picture
        this.redraw()
        this.canvasTarget.setAttribute("data-loaded", "")
      } else {
        this.keepSaved = true
      }
    })
    picture.src = this.imageUrlValue
  }

  start(event) {
    if (this.stroke) return

    event.preventDefault()
    this.canvasTarget.setPointerCapture(event.pointerId)
    this.pointerId = event.pointerId
    this.stroke = { colour: this.colour, points: [ this.pointAt(event) ] }
    this.strokes.push(this.stroke)
    this.changed = true
    this.paint(this.stroke)
  }

  move(event) {
    if (!this.stroke || event.pointerId !== this.pointerId) return

    this.stroke.points.push(this.pointAt(event))
    this.paint({ colour: this.stroke.colour, points: this.stroke.points.slice(-2) })
  }

  end(event) {
    if (event.pointerId === this.pointerId) this.stroke = null
  }

  pick({ currentTarget }) {
    this.swatchTargets.forEach(swatch => swatch.setAttribute("aria-pressed", swatch === currentTarget))
    this.colour = this.colourOf(currentTarget)
  }

  undo() {
    if (!this.strokes.pop()) return

    this.changed = true
    this.redraw()
  }

  clear() {
    this.loading = Promise.resolve()
    this.abandon?.()
    this.keepSaved = false
    this.strokes = []
    this.picture = null
    this.changed = true
    this.redraw()
  }

  // All done. It waits for the saved picture, so the export has it as its first layer. toBlob is asynchronous, so
  // the PNG goes into the file input and the form submits only inside its callback; requestSubmit fires that second
  // submit at once, and it goes through. Nothing changed, or the saved picture didn't load: back to the step, saving
  // nothing.
  async save(event) {
    if (this.exported) {
      this.exported = false
      return
    }

    event.preventDefault()
    if (this.saving) return

    this.saving = true
    await this.loading
    if (!this.changed || this.keepSaved) return Turbo.visit(this.stepUrlValue)

    this.canvasTarget.toBlob(blob => {
      const transfer = new DataTransfer()
      transfer.items.add(new File([ blob ], "drawing.png", { type: "image/png" }))
      this.inputTarget.files = transfer.files
      this.exported = true
      this.formTarget.requestSubmit(this.doneTarget)
    }, "image/png")
  }

  // A submission that never reached the server (Turbo leaves the page as it is): All done can export again.
  submitted({ detail: { success } }) {
    if (!success) this.saving = false
  }

  redraw() {
    this.paper.fillStyle = getComputedStyle(this.canvasTarget).backgroundColor
    this.paper.fillRect(0, 0, WIDTH, HEIGHT)
    if (this.picture) this.paper.drawImage(this.picture, 0, 0, WIDTH, HEIGHT)
    this.strokes.forEach(stroke => this.paint(stroke))
  }

  // A single point is a dot: a round cap on a line of no length.
  paint({ colour, points }) {
    const [ first, ...rest ] = points
    this.paper.strokeStyle = colour
    this.paper.beginPath()
    this.paper.moveTo(first.x, first.y)
    ;(rest.length ? rest : [ first ]).forEach(point => this.paper.lineTo(point.x, point.y))
    this.paper.stroke()
  }

  pointAt(event) {
    const box = this.canvasTarget.getBoundingClientRect()
    return { x: (event.clientX - box.left) * WIDTH / box.width, y: (event.clientY - box.top) * HEIGHT / box.height }
  }

  colourOf(swatch) {
    return getComputedStyle(swatch).backgroundColor
  }
}
