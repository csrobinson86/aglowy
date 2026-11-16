// Lower case, without dots or spaces, as abbreviations are written in config/bible.yml (Bible::Book.normalize).
const normalize = text => text.toLowerCase().replace(/[.\s]/g, "")

// A book's name, the name for one chapter, and its abbreviations, normalized (Bible::Book#names).
const names = book => [ book.name, book.single, ...book.abbreviations ].map(normalize)

// What's typed after a "+": a book, or the start of one ("p", "1 co"), then perhaps a chapter, and verses as
// Bible::Reference::PATTERN reads them, any of which may still be half typed ("ps 37:", "ps 37:8-").
const TYPED = /^\s*(?<book>\d?\s*[a-z][a-z.\s]*?|\d)\s*(?:(?<chapter>\d+)(?:\s*[:\s]\s*(?:(?<firstVerse>\d+)(?:\s*(?<joiner>[-–,])\s*(?<lastVerse>\d+)?)?)?)?)?\s*$/i

// A Bible reference written our way, by the same rules as Bible::Reference#to_s and #id
// (docs/design/scripture-links.md, Decisions): "Psalm" for one psalm, "8, 9" for two verses in a row, "8-11" for
// more, and "Psalm 23" for a whole chapter. book is a book from the canon JSON; a whole chapter has no verses.
export default class Reference {
  // The books the text could be the start of, in canonical order (Bible::Book.match). A numbered book's name counts
  // without its number too, so "p" starts 1 and 2 Peter.
  static books(canon, text) {
    const prefix = normalize(text)
    return canon.filter(book => [ ...names(book), normalize(book.name.replace(/^\d /, "")) ].some(name => name.startsWith(prefix)))
  }

  // What the text after a "+" chooses so far, by the same rules as Bible::Reference.parse: the books it could
  // start, then the book it names exactly once a chapter or a space follows, and the chapter and verses that exist.
  // Verses typed that Bible::Reference.parse would refuse ("37:200", "37:8, 10") make it invalid, so it's never taken
  // for the whole chapter. Null when the text can't be the start of a reference.
  static typed(canon, text) {
    const parts = text.match(TYPED)?.groups
    const books = parts ? this.books(canon, parts.book) : []
    if (!books.length) return null

    const rest = text.slice(text.indexOf(parts.book) + parts.book.length)
    const book = /\d|\s$/.test(rest) ? books.find(book => names(book).includes(normalize(parts.book))) : null
    const chapter = Number(parts.chapter)
    if (!book?.verses[chapter - 1]) return { books, book }

    if (!parts.firstVerse) return { books, book, chapter }

    return { books, book, chapter, ...this.#verses(book, chapter, parts) }
  }

  // Verses only if they exist, and a comma only for two verses in a row.
  static #verses(book, chapter, { firstVerse, joiner, lastVerse }) {
    const [ first, last ] = [ Number(firstVerse), Number(lastVerse || firstVerse) ]
    const existing = first >= (book.first_verses?.[chapter] ?? 1) && last >= first && last <= book.verses[chapter - 1]
    if (!existing || (joiner === "," && lastVerse && last !== first + 1)) return { invalid: true }

    return { firstVerse: first, lastVerse: last }
  }

  constructor(book, chapter, firstVerse = null, lastVerse = firstVerse) {
    this.book = book
    this.chapter = chapter
    this.firstVerse = firstVerse
    this.lastVerse = lastVerse
  }

  // "19:37:8-9", what /scriptures/:id and Bible::Reference.find read.
  get id() {
    const verses = this.firstVerse ? [ ...new Set([ this.firstVerse, this.lastVerse ]) ].join("-") : null
    return [ this.book.number, this.chapter, verses ].filter(Boolean).join(":")
  }

  // "Psalms, chapter 37, verses 8 to 9", the match row's words for a typed reference.
  get description() {
    const chapter = `${this.book.name}, chapter ${this.chapter}`
    if (!this.firstVerse) return chapter

    return this.firstVerse === this.lastVerse ? `${chapter}, verse ${this.firstVerse}` : `${chapter}, verses ${this.firstVerse} to ${this.lastVerse}`
  }

  toString() {
    return this.firstVerse ? `${this.book.single} ${this.chapter}:${this.#versesText}` : `${this.book.single} ${this.chapter}`
  }

  get #versesText() {
    switch (this.lastVerse - this.firstVerse) {
      case 0: return `${this.firstVerse}`
      case 1: return `${this.firstVerse}, ${this.lastVerse}`
      default: return `${this.firstVerse}-${this.lastVerse}`
    }
  }
}
