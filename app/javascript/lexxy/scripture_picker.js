import { Extension, CustomActionTextAttachmentNode, Lexical } from "@37signals/lexxy"

const { $getSelection, $setSelection, $createTextNode } = Lexical

// The one attachment type a notes editor permits (Bible::Reference::CONTENT_TYPE).
const CONTENT_TYPE = "application/vnd.actiontext.scripture"

// The Octicon book, as Lexxy draws its own toolbar icons.
const BOOK_ICON = `<svg aria-hidden="true" viewBox="0 0 16 16" width="16" height="16" fill="currentColor"><path d="M0 1.75A.75.75 0 0 1 .75 1h4.253c1.227 0 2.317.59 3 1.501A3.743 3.743 0 0 1 11.006 1h4.245a.75.75 0 0 1 .75.75v10.5a.75.75 0 0 1-.75.75h-4.507a2.25 2.25 0 0 0-1.591.659l-.622.621a.75.75 0 0 1-1.06 0l-.622-.621A2.25 2.25 0 0 0 5.258 13H.75a.75.75 0 0 1-.75-.75Zm7.251 10.324.004-5.073-.002-2.253A2.25 2.25 0 0 0 5.003 2.5H1.5v9h3.757a3.75 3.75 0 0 1 1.994.574ZM8.755 4.75l-.004 7.322a3.752 3.752 0 0 1 1.992-.572H14.5v-9h-3.495a2.25 2.25 0 0 0-2.25 2.25Z"></path></svg>`

// The open session, in any editor on the page (docs/design/scripture-links.md, Sessions). Opening another ends it.
let openSession = null
let lastSessionId = 0

// The Scripture button in a notes editor's toolbar, and the only code that touches Lexxy. It opens the picker
// (ScripturePickerComponent) with scripture-picker:open { session } and inserts the link the picker sends back with
// scripture-picker:insert, but only for the open session, in this editor, and the picker's current reference: a late
// response from an ended session, or for a reference since changed, is dropped (Traps 9). Lexxy calls its extension
// API experimental, so test/system/scripture_links_test.rb runs before any Lexxy upgrade (Traps 2).
export default class ScripturePicker extends Extension {
  #button

  // Only editors that permit scripture links: the notes editors.
  get enabled() {
    return [ this.editorConfig.get("permittedAttachmentTypes") ].flat().join(" ").split(/\s+/).includes(CONTENT_TYPE)
  }

  // Lexxy calls this only for an enabled extension, and disposes only those, so the listeners start here.
  initializeToolbar(toolbar) {
    document.addEventListener("scripture-picker:insert", this.#insert)
    document.addEventListener("scripture-picker:close", this.#close)

    this.#button = document.createElement("button")
    Object.assign(this.#button, { type: "button", name: "scripture", title: "Scripture", className: "lexxy-editor__toolbar-button scripture-picker-button" })
    this.#button.dataset.scripturePickerOpener = ""
    this.#button.dataset.preventOverflow = "true"
    this.#button.innerHTML = `${BOOK_ICON}<span>Scripture</span>`
    // Keep the caret in the editor: the session saves it.
    this.#button.addEventListener("mousedown", event => event.preventDefault())
    this.#button.addEventListener("click", this.#open)
    toolbar.insertBefore(this.#button, toolbar.querySelector(":scope > button[name=quote]"))
  }

  dispose() {
    document.removeEventListener("scripture-picker:insert", this.#insert)
    document.removeEventListener("scripture-picker:close", this.#close)
    this.#button?.remove()

    if (this.#ownsOpenSession) {
      document.dispatchEvent(new CustomEvent("scripture-picker:end", { detail: { session: openSession.id } }))
      openSession = null
    }
  }

  #open = () => {
    const selection = this.editorElement.editor.getEditorState().read(() => $getSelection()?.clone() ?? null)
    openSession = { id: ++lastSessionId, editorElement: this.editorElement, selection }
    this.editorElement.dispatchEvent(new CustomEvent("scripture-picker:open", { bubbles: true, detail: { session: openSession.id } }))
  }

  #close = ({ detail: { session, restoreFocus } }) => {
    if (!this.#ownsOpenSession || openSession.id !== session) return

    openSession = null
    if (restoreFocus) this.editorElement.focus()
  }

  #insert = ({ target: picker, detail: { session: id, sgid, html, reference } }) => {
    const session = openSession
    if (!this.#ownsOpenSession || session.id !== id || reference !== picker.dataset.scripturePickerReferenceValue) return

    openSession = null
    // On a phone, tapping the grid takes focus from the editor, so the caret is put back before inserting (Traps 3).
    this.editorElement.editor.update(() => {
      if (session.selection) $setSelection(session.selection.clone())
      const node = new CustomActionTextAttachmentNode({ sgid, contentType: CONTENT_TYPE, innerHtml: html })
      this.editorElement.contents.insertAtCursor(node, $createTextNode(" "))
    })
    this.editorElement.focus()
  }

  get #ownsOpenSession() {
    return openSession?.editorElement === this.editorElement
  }
}
