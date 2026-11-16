import { Controller } from "@hotwired/stimulus"
import Reference from "../javascript/bible/reference"

// The scripture picker (ScripturePickerComponent, docs/design/scripture-links.md, The picker). The Lexxy extension
// opens it on an editor with scripture-picker:open { session, query }, and opens it again with the same session as a
// query typed after "+" changes. A book, then a chapter, then verses: one tap picks a verse, a second makes a range
// and a third starts again; Insert with no verse is the whole chapter. A query chooses the same way as you type it
// (Typing a reference), and the keys the editor hands over with scripture-picker:key move through the books and
// pick or insert. Insert asks the server for the reference's sgid and hands it back with scripture-picker:insert
// { session, sgid, html, reference, query }. Close, Cancel, Esc, a click outside, and a space after a query that
// can't be a reference end the session with scripture-picker:close { session }.
export default class extends Controller {
  static targets = [ "canon", "title", "match", "matchReference", "matchDescription", "books", "chaptersHeading", "chapters", "versesHeading", "verses", "reference", "insert", "bookTemplate", "numberTemplate" ]
  static values = { url: String, step: String, session: Number, reference: String }

  connect() {
    this.canon = JSON.parse(this.canonTarget.textContent)
    this.booksTarget.replaceChildren(...this.canon.map(book => this.#bookOption(book)))
  }

  // From "+" the editor keeps focus, so the person can go on typing.
  open({ target: editor, detail: { session, query } }) {
    if (session === this.sessionValue && !this.element.hidden) return this.#type(query)

    this.#cancelLookup()
    this.editor = editor
    this.sessionValue = session
    this.query = query
    this.#choose({})
    this.stepValue = "book"
    this.element.hidden = false
    this.#saveCaret()
    this.position()

    if (query) {
      this.#type(query)
    } else {
      this.#filter(this.canon)
      this.#focus(this.booksTarget)
    }
  }

  // Enter, Esc and the arrows from the editor while a query is typed. Cancelling the event tells the editor the key
  // was used here.
  key(event) {
    const { session, key } = event.detail
    if (session !== this.sessionValue || this.element.hidden) return

    const options = this.#visibleOptions
    const active = options.findIndex(option => option.classList.contains("scripture-picker__book--active"))

    if (key === "Escape") {
      this.close()
    } else if (key === "Enter" && this.#reference) {
      this.insert()
    } else if (key === "Enter" && this.stepValue === "book" && active >= 0) {
      options[active].click()
    } else if (key.startsWith("Arrow") && this.stepValue === "book" && options.length) {
      this.#activate(options[Math.min(Math.max(active + (key === "ArrowDown" ? 1 : -1), 0), options.length - 1)])
    } else {
      return
    }
    event.preventDefault()
  }

  // The extension ends a session when its editor goes away.
  end({ detail: { session } }) {
    if (session === this.sessionValue) this.#hide()
  }

  close() {
    this.#endSession({ restoreFocus: true })
  }

  closeOutside(event) {
    const path = event.composedPath()
    if (path.includes(this.element) || path.some(node => node.dataset?.scripturePickerOpener !== undefined)) return

    this.#endSession({ restoreFocus: false })
  }

  back() {
    this.stepValue = this.stepValue === "verses" ? "chapter" : "book"
    this.#focus(this.stepValue === "chapter" ? this.chaptersTarget : this.booksTarget)
  }

  pickBook({ currentTarget }) {
    if (this.request) return

    this.#choose({ book: this.canon[currentTarget.dataset.number - 1] })
    this.stepValue = "chapter"
    this.#focus(this.chaptersTarget)
  }

  pickChapter({ currentTarget }) {
    this.#choose({ book: this.book, chapter: Number(currentTarget.value) })
    this.stepValue = "verses"
    this.#focus(this.versesTarget)
  }

  pickVerse({ currentTarget }) {
    const verse = Number(currentTarget.value)
    const { book, chapter, firstVerse } = this

    if (firstVerse && !this.ranged) {
      this.#choose({ book, chapter, firstVerse: Math.min(firstVerse, verse), lastVerse: Math.max(firstVerse, verse), ranged: true })
    } else {
      this.#choose({ book, chapter, firstVerse: verse, lastVerse: verse })
    }
  }

  // One lookup at a time, for the reference chosen when Insert was pressed. Everything that could change the
  // reference is disabled until it answers, and ending the session aborts it (Sessions).
  async insert() {
    const reference = this.#reference
    if (!reference || this.request) return

    const request = { session: this.sessionValue, reference: reference.id, query: this.query, abort: new AbortController() }
    this.request = request
    this.#busy(true)

    try {
      const response = await fetch(this.urlValue.replace(":id", reference.id), { headers: { Accept: "application/json" }, signal: request.abort.signal })
      if (!response.ok) return

      const { sgid, html } = await response.json()
      if (this.request !== request) return

      this.dispatch("insert", { detail: { session: request.session, sgid, html, reference: request.reference, query: request.query } })
      this.#hide()
    } catch {
      // Aborted, or the network dropped: Insert can be pressed again.
    } finally {
      if (this.request === request) this.#cancelLookup()
    }
  }

  moveThroughBooks(event) {
    const options = [ ...this.booksTarget.children ]
    const index = options.indexOf(event.target)

    switch (event.key) {
      case "ArrowDown": this.#focusOption(options[index + 1]); break
      case "ArrowUp": this.#focusOption(options[index - 1]); break
      case "Enter": case " ": event.target.click(); break
      default: return
    }
    event.preventDefault()
  }

  // Below 768px the picker fills the editor's width just under the caret's line; from 768px it's anchored at the
  // caret, 760px wide (or the editor's width), and kept inside the editor.
  position() {
    if (this.element.hidden || !this.editor?.isConnected) return

    const area = this.#editableArea.getBoundingClientRect()
    const parent = this.element.offsetParent ?? document.documentElement
    const origin = parent.getBoundingClientRect()
    const phone = !matchMedia("(min-width: 768px)").matches

    this.element.style.width = phone ? `${area.width}px` : ""
    this.element.style.maxWidth = `${area.width}px`
    const left = phone ? area.left : Math.min(area.left + this.caret.left, area.right - this.element.offsetWidth)
    this.element.style.left = `${left - origin.left + parent.scrollLeft}px`
    this.element.style.top = `${area.top + this.caret.bottom - origin.top + parent.scrollTop}px`
  }

  stepValueChanged() {
    this.#label()
  }

  // The header's title and the dialog's name follow the step.
  #label() {
    const { book, chapter } = this
    const [ title, label ] = {
      book: [ "Book", "Choose a book" ],
      chapter: [ `${book?.name} · Chapter`, `Choose a chapter of ${book?.name}` ],
      verses: [ `${book?.single} ${chapter} · Verses`, `Choose verses in ${book?.single} ${chapter}` ]
    }[this.stepValue]

    this.titleTarget.textContent = title
    this.element.setAttribute("aria-label", label)
  }

  // What the query after "+" chooses, as it's typed: the books it could start, the first of them active, then the
  // book, chapter and verses it names, and on desktop a match row for a reference (frame desktop-typed.png). A lookup
  // for the query before is dropped (Sessions). A query that can't be a reference is left alone until a space
  // follows it, which ends the session.
  #type(query) {
    this.query = query
    this.#cancelLookup()

    const text = query.slice(1)
    const typed = text ? Reference.typed(this.canon, text) : { books: this.canon }
    if (!typed && /\s/.test(text)) return this.#endSession({ restoreFocus: false })

    this.#filter(typed?.books ?? [])
    this.#activate(this.#visibleOptions[0])
    this.#choose({ ...typed, ranged: typed?.firstVerse !== typed?.lastVerse })
    this.stepValue = typed?.chapter ? "verses" : typed?.book ? "chapter" : "book"

    const reference = this.#reference
    this.matchTarget.hidden = !reference
    this.matchReferenceTarget.textContent = reference?.toString() ?? ""
    this.matchDescriptionTarget.textContent = reference?.description ?? ""
  }

  // The selection: a book, a chapter and verses, each optional from the end. Invalid verses typed after "+" leave no
  // reference to insert. Grids are rebuilt only for a new book or
  // chapter, so a tap never removes the button it landed on.
  #choose({ book = null, chapter = null, firstVerse = null, lastVerse = null, ranged = false, invalid = false }) {
    if (book !== this.book) this.#fillGrid(this.chaptersTarget, book ? 1 : 0, book?.verses.length ?? 0, "pickChapter")
    if (book !== this.book || chapter !== this.chapter) {
      this.#fillGrid(this.versesTarget, chapter ? book.first_verses?.[chapter] ?? 1 : 0, chapter ? book.verses[chapter - 1] : 0, "pickVerse")
    }
    Object.assign(this, { book, chapter, firstVerse, lastVerse, ranged, invalid })

    for (const option of this.booksTarget.children) option.setAttribute("aria-selected", Number(option.dataset.number) === book?.number)
    this.#press(this.chaptersTarget, number => number === chapter)
    this.#press(this.versesTarget, number => firstVerse && number >= firstVerse && number <= lastVerse)
    this.chaptersHeadingTarget.textContent = book ? `${book.name} · Chapter` : "Chapter"
    this.versesHeadingTarget.textContent = chapter ? `${book.single} ${chapter} · Verses` : "Verses"

    const reference = this.#reference
    this.matchTarget.hidden = true
    this.referenceTarget.textContent = reference?.toString() ?? ""
    this.referenceValue = reference?.id ?? ""
    this.insertTarget.disabled = !reference
    this.#label()
  }

  get #reference() {
    return this.chapter && !this.invalid ? new Reference(this.book, this.chapter, this.firstVerse, this.lastVerse) : null
  }

  #endSession({ restoreFocus }) {
    if (this.element.hidden) return

    this.#hide()
    this.dispatch("close", { detail: { session: this.sessionValue, restoreFocus } })
  }

  #hide() {
    this.#cancelLookup()
    this.#activate(null)
    this.element.hidden = true
  }

  #cancelLookup() {
    this.request?.abort.abort()
    this.request = null
    this.#busy(false)
  }

  #busy(busy) {
    if (busy) this.element.setAttribute("aria-busy", "true")
    else this.element.removeAttribute("aria-busy")
    this.insertTarget.disabled = busy || !this.#reference
    for (const button of this.element.querySelectorAll(".scripture-picker__number")) button.disabled = busy
    for (const option of this.booksTarget.children) option.setAttribute("aria-disabled", busy)
  }

  // Only the books given show in the list.
  #filter(books) {
    const numbers = new Set(books.map(book => book.number))
    for (const option of this.booksTarget.children) option.hidden = !numbers.has(Number(option.dataset.number))
    this.#activate(null)
  }

  get #visibleOptions() {
    return [ ...this.booksTarget.children ].filter(option => !option.hidden)
  }

  // The book Enter picks while focus stays in the editor, which points screen readers at it, as Lexxy's prompt does.
  #activate(option) {
    for (const other of this.booksTarget.children) other.classList.toggle("scripture-picker__book--active", other === option)
    option?.scrollIntoView({ block: "nearest" })

    const editable = this.#editableArea
    if (option) {
      editable.setAttribute("aria-controls", this.booksTarget.id)
      editable.setAttribute("aria-activedescendant", option.id)
    } else {
      editable.removeAttribute("aria-controls")
      editable.removeAttribute("aria-activedescendant")
    }
  }

  #bookOption(book) {
    const option = this.bookTemplateTarget.content.firstElementChild.cloneNode(true)
    option.id = `scripture-picker-book-${book.number}`
    option.dataset.number = book.number
    option.querySelector(".scripture-picker__book-name").textContent = book.name
    option.querySelector(".scripture-picker__book-count").textContent = book.verses.length
    option.querySelector(".scripture-picker__unit").textContent = book.verses.length === 1 ? " chapter" : " chapters"
    return option
  }

  #fillGrid(grid, first, last, action) {
    const buttons = []
    for (let number = first; number && number <= last; number++) {
      const button = this.numberTemplateTarget.content.firstElementChild.cloneNode(true)
      button.value = button.textContent = number
      button.dataset.action = `scripture-picker#${action}`
      buttons.push(button)
    }
    grid.replaceChildren(...buttons)
  }

  #press(grid, pressed) {
    for (const button of grid.children) button.setAttribute("aria-pressed", Boolean(pressed(Number(button.value))))
  }

  // The selected item in a region, or its first; a book list takes focus on one option at a time.
  #focus(region) {
    const item = region.querySelector("[aria-selected=true], [aria-pressed=true]") ?? region.firstElementChild
    if (region === this.booksTarget) this.#focusOption(item)
    else item?.focus()
  }

  #focusOption(option) {
    if (!option) return

    for (const other of this.booksTarget.children) other.tabIndex = other === option ? 0 : -1
    option.focus()
  }

  // Where the caret is in the editor, kept relative to the editable area so the picker can follow a resize.
  #saveCaret() {
    const area = this.#editableArea.getBoundingClientRect()
    const selection = window.getSelection()
    const range = selection.rangeCount && this.#editableArea.contains(selection.anchorNode) ? selection.getRangeAt(0) : null
    const container = range?.startContainer
    const rect = range?.getClientRects()[0] ?? (container instanceof Element ? container : container?.parentElement)?.getBoundingClientRect() ?? area

    this.caret = { left: rect.left - area.left, bottom: Math.max(rect.bottom - area.top, 0) }
  }

  get #editableArea() {
    return this.editor.querySelector("[contenteditable]") ?? this.editor
  }
}
