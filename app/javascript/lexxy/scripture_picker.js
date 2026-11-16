import { Extension, CustomActionTextAttachmentNode, Lexical } from "@37signals/lexxy"

const {
  $getSelection, $setSelection, $createTextNode, $isRangeSelection, $isTextNode, mergeRegister,
  KEY_ENTER_COMMAND, KEY_ESCAPE_COMMAND, KEY_ARROW_UP_COMMAND, KEY_ARROW_DOWN_COMMAND, COMMAND_PRIORITY_CRITICAL
} = Lexical

// The one attachment type a notes editor permits (Bible::Reference::CONTENT_TYPE).
const CONTENT_TYPE = "application/vnd.actiontext.scripture"

// The Octicon book, as Lexxy draws its own toolbar icons.
const BOOK_ICON = `<svg aria-hidden="true" viewBox="0 0 16 16" width="16" height="16" fill="currentColor"><path d="M0 1.75A.75.75 0 0 1 .75 1h4.253c1.227 0 2.317.59 3 1.501A3.743 3.743 0 0 1 11.006 1h4.245a.75.75 0 0 1 .75.75v10.5a.75.75 0 0 1-.75.75h-4.507a2.25 2.25 0 0 0-1.591.659l-.622.621a.75.75 0 0 1-1.06 0l-.622-.621A2.25 2.25 0 0 0 5.258 13H.75a.75.75 0 0 1-.75-.75Zm7.251 10.324.004-5.073-.002-2.253A2.25 2.25 0 0 0 5.003 2.5H1.5v9h3.757a3.75 3.75 0 0 1 1.994.574ZM8.755 4.75l-.004 7.322a3.752 3.752 0 0 1 1.992-.572H14.5v-9h-3.495a2.25 2.25 0 0 0-2.25 2.25Z"></path></svg>`

// The keys the editor hands the picker while a session is open, and the names the picker knows them by.
const KEYS = new Map([
  [ KEY_ENTER_COMMAND, "Enter" ], [ KEY_ESCAPE_COMMAND, "Escape" ], [ KEY_ARROW_UP_COMMAND, "ArrowUp" ], [ KEY_ARROW_DOWN_COMMAND, "ArrowDown" ]
])

// A "+" after a space or at the start of the text, and everything after it up to the caret: the query.
const QUERY = /(?:^|\s)(\+[^+\n]*)$/

// The open session, in any editor on the page (docs/design/scripture-links.md, Sessions). Opening another ends it.
let openSession = null
let lastSessionId = 0

// Ends the open session and stops taking keys from its editor.
function endOpenSession() {
  openSession?.stopKeys()
  openSession = null
}

// The Scripture button in a notes editor's toolbar, the "+" that opens the picker as you type, and the only code that
// touches Lexxy. It opens the picker (ScripturePickerComponent) with scripture-picker:open { session, query }, sends it
// the query again as it changes, and inserts the link the picker sends back with scripture-picker:insert, but only for
// the open session, in this editor, and the picker's current reference and query: a late response from an ended
// session, or for a reference or query since changed, is dropped (Traps 9). Lexxy calls its extension API
// experimental, so test/system/scripture_links_test.rb runs before any Lexxy upgrade (Traps 2).
export default class ScripturePicker extends Extension {
  #button

  // Only editors that permit scripture links: the notes editors.
  get enabled() {
    return [ this.editorConfig.get("permittedAttachmentTypes") ].flat().join(" ").split(/\s+/).includes(CONTENT_TYPE)
  }

  get lexicalExtension() {
    return this.defineExtension({
      name: "aglowy/scripture-picker",
      register: editor => editor.registerUpdateListener(update => this.#follow(update))
    })
  }

  // Lexxy calls this only for an enabled extension, and disposes only those, so the listeners start here.
  initializeToolbar(toolbar) {
    document.addEventListener("scripture-picker:insert", this.#insert)
    document.addEventListener("scripture-picker:close", this.#close)

    this.#button = document.createElement("button")
    Object.assign(this.#button, { type: "button", name: "scripture", title: "Scripture", className: "lexxy-editor__toolbar-button scripture-picker-button" })
    this.#button.dataset.scripturePickerOpener = ""
    this.#button.dataset.preventOverflow = "true"
    this.#button.innerHTML = `${BOOK_ICON}<span>Scripture</span><kbd class="scripture-picker-button__hint" aria-hidden="true">+</kbd>`
    // Keep the caret in the editor: the session saves it.
    this.#button.addEventListener("mousedown", event => event.preventDefault())
    this.#button.addEventListener("click", this.#open)
    toolbar.insertBefore(this.#button, toolbar.querySelector(":scope > button[name=quote]"))
  }

  dispose() {
    document.removeEventListener("scripture-picker:insert", this.#insert)
    document.removeEventListener("scripture-picker:close", this.#close)
    this.#button?.remove()

    if (this.#ownsOpenSession) this.#end()
  }

  #open = () => {
    const selection = this.editorElement.editor.getEditorState().read(() => $getSelection()?.clone() ?? null)
    this.#start({ query: "", selection })
  }

  // A session takes Enter, Esc and the arrows from its editor, before Lexical's own handlers, the way Lexxy's prompt
  // does, and only until it ends: otherwise they work in the editor as usual.
  #start({ query, selection }) {
    endOpenSession()

    const editor = this.editorElement.editor
    const stopKeys = mergeRegister(...[ ...KEYS ].map(([ command, key ]) => editor.registerCommand(command, event => this.#key(event, key), COMMAND_PRIORITY_CRITICAL)))
    openSession = { id: ++lastSessionId, editorElement: this.editorElement, query, selection, stopKeys }
    this.#show()
  }

  #show() {
    const { id: session, query } = openSession
    this.editorElement.dispatchEvent(new CustomEvent("scripture-picker:open", { bubbles: true, detail: { session, query } }))
  }

  // While the editor has focus, a "+" just typed at the start of a word opens a session (an update that only moves
  // the caret, as putting focus back after Esc does, opens nothing). While a session from "+" is
  // open, every update reads the query again, from the "+" to the caret, and saves the caret, so the caret saved is
  // always the end of the query as it now stands (Traps 3). A caret moved off the query ends the session.
  #follow({ editorState, dirtyLeaves }) {
    if (!this.editorElement.editor.getRootElement()?.contains(document.activeElement)) return

    const typed = editorState.read(() => this.#typed())
    if (this.#ownsOpenSession && openSession.query) {
      if (!typed) return this.#end()

      const changed = typed.query !== openSession.query
      Object.assign(openSession, typed)
      if (changed) this.#show()
    } else if (typed?.query === "+" && dirtyLeaves.size) {
      this.#start(typed)
    }
  }

  // The query before a collapsed caret, and the caret, or null. A "+" at the start of a text node is the start of a
  // word only if the node before it ends in a space or a line break, or there's none.
  #typed() {
    const selection = $getSelection()
    if (!$isRangeSelection(selection) || !selection.isCollapsed()) return null

    const node = selection.anchor.getNode()
    if (!$isTextNode(node)) return null

    const text = node.getTextContent().slice(0, selection.anchor.offset)
    const query = text.match(QUERY)?.[1]
    if (!query || (text.startsWith(query) && !/(^|\s)$/.test(node.getPreviousSibling()?.getTextContent() ?? ""))) return null

    return { query, selection: selection.clone() }
  }

  // The picker cancels the keys it uses; the rest go on to the editor.
  #key(event, key) {
    const detail = { session: openSession.id, key }
    const used = !this.editorElement.dispatchEvent(new CustomEvent("scripture-picker:key", { bubbles: true, cancelable: true, detail }))
    if (used) event?.preventDefault()
    return used
  }

  #end() {
    const session = openSession.id
    endOpenSession()
    document.dispatchEvent(new CustomEvent("scripture-picker:end", { detail: { session } }))
  }

  #close = ({ detail: { session, restoreFocus } }) => {
    if (!this.#ownsOpenSession || openSession.id !== session) return

    endOpenSession()
    if (restoreFocus) this.editorElement.focus()
  }

  #insert = ({ target: picker, detail: { session: id, sgid, html, reference, query = "" } }) => {
    const session = openSession
    if (!this.#ownsOpenSession || session.id !== id || reference !== picker.dataset.scripturePickerReferenceValue || query !== session.query) return

    endOpenSession()
    // On a phone, tapping the grid takes focus from the editor, so the caret is put back before inserting (Traps 3).
    // From "+" it's the end of the query, which the link replaces whole; Lexxy adds the space after it, as it does
    // for its own prompts.
    this.editorElement.editor.update(() => {
      if (session.selection) $setSelection(session.selection.clone())
      const node = new CustomActionTextAttachmentNode({ sgid, contentType: CONTENT_TYPE, innerHtml: html })
      if (query) this.editorElement.contents.replaceTextBackUntil(query, node)
      else this.editorElement.contents.insertAtCursor(node, $createTextNode(" "))
    })
    this.editorElement.focus()
  }

  get #ownsOpenSession() {
    return openSession?.editorElement === this.editorElement
  }
}
