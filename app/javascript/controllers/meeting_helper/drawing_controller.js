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
  // can't load, All done keeps it rather than saving over it without it.
  load() {
    const picture = new Image()
    picture.crossOrigin = "anonymous"
    picture.onload = () => {
      this.picture = picture
      this.redraw()
      this.canvasTarget.setAttribute("data-loaded", "")
    }
    picture.onerror = () => { this.keepSaved = true }
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
    this.strokes = []
    this.picture = null
    this.changed = true
    this.redraw()
  }

  // All done. toBlob is asynchronous, so the PNG goes into the file input and the form submits only inside its
  // callback; that second submit finds the file and goes through. Nothing changed, or the saved picture didn't load:
  // back to the step, saving nothing.
  save(event) {
    if (this.inputTarget.files.length > 0) return

    event.preventDefault()
    if (this.saving) return
    if (!this.changed || this.keepSaved) return Turbo.visit(this.stepUrlValue)

    this.saving = true
    this.canvasTarget.toBlob(blob => {
      const transfer = new DataTransfer()
      transfer.items.add(new File([ blob ], "drawing.png", { type: "image/png" }))
      this.inputTarget.files = transfer.files
      this.formTarget.requestSubmit(this.doneTarget)
    }, "image/png")
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
