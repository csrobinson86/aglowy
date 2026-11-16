// A Bible reference written our way, by the same rules as Bible::Reference#to_s and #id
// (docs/design/scripture-links.md, Decisions): "Psalm" for one psalm, "8, 9" for two verses in a row, "8-11" for
// more, and "Psalm 23" for a whole chapter. book is a book from the canon JSON; a whole chapter has no verses.
export default class Reference {
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
