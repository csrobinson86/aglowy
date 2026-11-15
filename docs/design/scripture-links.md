# Scripture links in notes

Type `+` in any notes editor, or tap **Scripture** in its toolbar, and a picker opens: a book, then a chapter, then verses. The chosen reference goes into the note as a link, "Psalm 37:8, 9", that opens that passage in the New World Translation on jw.org. A reference someone types by hand, like "matt 24:14", becomes the same link when the note is saved.

Read this before touching `Bible::Book`, `Bible::Reference`, `Bible::Linker`, the `ScriptureLinkable` concern, `ScripturePickerComponent`, the Lexxy extension in `app/javascript/lexxy/scripture_picker.js`, or the options on a notes `rich_text_area`. Stories live under the **SCRIPT-01** epic. Mockup frames are in `docs/design/scripture-links/`.

It builds on two docs:
- `docs/design/meeting-notes.md`: the notes editors live there.
- `docs/design/family-studies.md`: Lexxy, Action Text and the sanitizer.

## Decisions (Casey, 15 Nov)

- **The picker uses grids:** a book list, then a chapter grid, then a verse grid, as in the mockups. A verse range is two taps. It opens from a `+` typed at the start of a word or from the toolbar's **Scripture** button.
- **Typed references work too.** On desktop, "+ps 37:8-9" fills the picker as you type, and Enter inserts it. Anywhere, a reference typed without the picker is linked when the note is saved.
- **Links only, no verse text.** Showing or storing the verse text means copying Watch Tower content, and jw.org's terms restrict copying and automated downloading. Verse text waits for the jw.org sourcing and terms decision.
- **We accept the upgrade risk of building on Lexxy's experimental extension API.** Lexxy's documented prompts can only show a list. The grid picker therefore uses `Lexxy.Extension`, which Lexxy calls experimental and may change without notice. A system test catches breakage, and **every Lexxy upgrade runs `test/system/scripture_links_test.rb` before anything else**.
- **References are written our way:** the singular "Psalm" for one psalm, a comma and space between two verses ("8, 9"), and a hyphen for three or more ("8-11").

## What SCRIPT-01 builds, and what comes later

| In SCRIPT-01 | Later |
| --- | --- |
| The Bible canon data and `Bible::Reference` | Verse text under the link (needs the terms decision) |
| Notes editors that accept scripture links and nothing else | "Every note where I wrote about Psalm 37" (a citation index) |
| The grid picker, from the toolbar button and from `+` | A hover card on desktop links (frame `desktop-saved.png`) |
| Typing a whole reference into the picker on desktop | Other languages and Bible editions |
| Linking typed references when a note is saved | Scripture links in goals (goal bodies aren't rich text yet) |

## Where it works

Two notes editors today:
- the meeting note parts' notes (`MeetingNote::Part has_rich_text :notes`)
- family study session notes (`FamilyStudy::Session has_rich_text :notes`)

Both render through a `rich_text_area`, so one helper sets the options on both (see "Editor options").

## The canon data

`config/bible.yml` lists the 66 books in canonical order. Each book has:
- `number` (1–66)
- `name` ("Psalms")
- `single` (the name for one chapter, "Psalm"; the same as `name` for every other book)
- `abbreviations`: the short forms people type, all lower case, no dots. For example `ps psa psalm` for Psalms, `mt matt` for Matthew, `1co 1cor` for 1 Corinthians.
- `verses`: an array with the verse count of each chapter. Its length is the chapter count.

Verse counts follow the New World Translation's numbering. Where the NWT leaves a verse out but keeps its number (such as Matthew 17:21), the number still counts. These are facts about the Bible's structure, not Watch Tower text.

Abbreviations are curated, and no abbreviation may belong to two books. Leave out short forms that collide or read as ordinary words: no "jo", "am", "is", "job" for Joel, or "acts" as an abbreviation. A book's own full name always matches.

The same data reaches the browser as JSON inside the picker component, so the browser and server never disagree about how many verses a chapter has.

## Models

### `Bible::Book`

A PORO (`Data`) loaded once from `config/bible.yml`.
- `Bible::Book.all` returns the 66 books.
- `Bible::Book.find(number)` raises `ActiveRecord::RecordNotFound` for a number that isn't a book.
- `Bible::Book.match(text)` returns the books whose name or abbreviation starts with the text, case-insensitive and ignoring dots and spaces ("1 cor", "1cor." and "1Co" all match), in canonical order.
- Each book has `chapters` (the count) and `verses_in(chapter)`.

### `Bible::Reference`

A value object (`Data.define(:book, :chapter, :first_verse, :last_verse)`), with verses optional for a whole chapter. It is the Action Text attachable.

- `Bible::Reference.parse(text)` reads "psalms 37:8,9", "Ps 37:8-9", "ps 37 8", "1 cor 13:4-7" and "matt 24:14". It returns nil when the text isn't a valid reference.
  - **Strict:** the book must match, and the chapter and verses must exist (`verses_in(chapter)`).
  - A comma joins only two verses in a row ("8, 9"); a hyphen gives any range ("8-11"). Verses that aren't in a row ("8, 10") aren't supported in SCRIPT-01, so `parse` returns nil for them.
- `to_s` writes the reference our way: "Psalm 37:8, 9", "1 Corinthians 13:4-7", "Psalm 23" for a whole chapter.
- `jw_url` returns `https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=19037008-19037009`. The `bible` parameter is BBCCCVVV: book, chapter and verse padded to 2, 3 and 3 digits, with `-` before the last verse of a range. A whole chapter runs from verse 1 to its last verse. This is the format JW Library's share links use. The first story opens a few links by hand to confirm it, and notes the result in its PR.
- `id` is "19:37:8-9", and `Bible::Reference.find(id)` parses it back. That's all GlobalID needs, so `include GlobalID::Identification` gives the reference an sgid with no table.
- `include ActionText::Attachable`:
  - `attachable_content_type` returns `"application/vnd.actiontext.scripture"`. That's Lexxy's default for a prompt named "scripture", and the type the editor permits.
  - `to_attachable_partial_path` is `"bible/references/reference"`: a link, `class="scripture-link"`, `target="_blank"`, `rel="noopener"`, the text `to_s` and an Octicon `link-external` with `aria-hidden`.
  - The editor-side partial renders the same text, styled as a link but not clickable.
  - `attachable_plain_text_representation` is `to_s`, so plain-text exports and search read "Psalm 37:8, 9".

### `Bible::Linker`

A PORO that links references in a rich text body.
- `Bible::Linker.new(content).link` returns new `ActionText::Content` in which each plain-text reference is replaced by a scripture attachment.
- It only changes text outside links, attachments and code.
- It only links text that `Bible::Reference.parse` accepts **and** that has a chapter and a verse ("Matt 24:14", not "Matthew 24"). A sentence about "Job" or "Acts" never becomes a link.
- The book name must start at a word boundary, and the verse must end at one.

### `ScriptureLinkable`

A concern for models with rich text notes: `scripture_linkable :notes`. It adds:
- `link_scriptures`: rewrites the notes with `Bible::Linker`. Controllers call it explicitly before saving; no `before_save`.
- a validation that every attachment in the notes is a `Bible::Reference`. Anything else (an image, a pasted attachment, a forged sgid for another record) makes the record invalid with "Notes can only link scriptures".

## Editor options

The notes `rich_text_area` keeps uploads off and lets one kind of attachment in. The old `attachments: false` blocks every attachment, scripture links included, so it changes to:

```erb
form.rich_text_area :notes,
  "permitted-attachment-types": "application/vnd.actiontext.scripture",
  "remote-images": false,
  data: { direct_upload_url: "", blob_url_template: "", controller: "no-uploads" } do %>
  <%# the scripture prompt markup, see below %>
<% end %>
```

A shared partial (`app/views/scriptures/_notes_field_options`, or a helper `scripture_notes_options`) holds these, so both editors stay the same.

Uploads stay off three ways:
1. Lexxy's own check: `permittedAttachmentTypes` refuses every other content type.
2. A tiny Stimulus controller, `no-uploads`, cancels `lexxy:file-accept` for every file, so a dropped or pasted file never starts uploading.
3. The model validation above, on the server.

The sanitizer keeps `action-text-attachment` (Action Text's default) and still drops `embed video audio source`.

## The picker

### Pieces

- **`ScripturePickerComponent`** (ViewComponent, sidecar ERB).
  - It renders the picker once per page, hidden, with the canon data as JSON in a `<script type="application/json">`.
  - It contains everything else as server-rendered markup: the header (title, Back, Close), three regions (books, chapters, verses), the footer (the reference text, Cancel, Insert as Primer `Button`s), and `<template>`s for one book row and one number button.
  - The household layout renders it when the page has a notes editor (`content_for :scripture_picker`).
- **Stimulus `scripture-picker` controller** on the component. It fills the book list from the JSON, clones the number-button template for chapters and verses, tracks the selection, and writes the reference text in our style (the same rules as `Bible::Reference#to_s`, mirrored in `app/javascript/bible/reference.js` with its own tests).
- **Lexxy extension `ScripturePicker`** (`app/javascript/lexxy/scripture_picker.js`, registered with `Lexxy.configure({ global: { extensions: [ ScripturePicker ] } })`). It's the only code that touches Lexxy:
  - `initializeToolbar(toolbar)` adds the **Scripture** button (a book icon, the label "Scripture", and on desktop a `+` key hint). It removes the button again in `dispose()`.
  - `lexicalExtension` registers, on the Lexical editor it is given:
    - an update listener that watches for `+` at the start of a word and then reads the text from the `+` to the caret (the query)
    - `KEY_ENTER_COMMAND`, `KEY_ESCAPE_COMMAND` and the arrow keys at `COMMAND_PRIORITY_CRITICAL`, but only while the picker is open
  - This is the same pattern Lexxy's own prompt uses (`lexxy.esm.js`, the prompt's `registerCommand(KEY_ENTER_COMMAND, …, COMMAND_PRIORITY_CRITICAL)`).
  - It opens and fills the picker by dispatching `scripture-picker:open` with the query, and listens for `scripture-picker:insert` with `{ sgid, html }`.
- **The sgid** comes from the server: `GET /scriptures/:id` (`ScripturesController#show`, `:id` like "19:37:8-9") returns `{ sgid, html, text }` as JSON. It needs a signed-in identity but no household. A Bible reference isn't anyone's record, so the controller skips `verify_authorized` and says why in a comment. Calling the server keeps signing on the server. The picker asks when Insert is pressed and disables Insert while it waits.

### Inserting

The extension inserts the way Lexxy's prompts do:

```js
editor.update(() => {
  $setSelection(savedSelection)            // the caret from when the picker opened
  const node = new CustomActionTextAttachmentNode({ sgid, contentType: "application/vnd.actiontext.scripture", innerHtml: html })
  if (query) editorElement.contents.replaceTextBackUntil(query, [ node, $createTextNode(" ") ])
  else editorElement.contents.insertAtCursor(node, $createTextNode(" "))
})
```

- `CustomActionTextAttachmentNode` comes from `@37signals/lexxy`. `$setSelection` and `$createTextNode` come from its `Lexical` export.
- Save the selection (`$getSelection().clone()`) when the picker opens. On a phone, tapping a grid button takes focus from the editor, and the keyboard closes.
- After inserting, focus goes back to the editor, with the caret after the space.

### Layout

| | Phone (below 768px) | Desktop |
| --- | --- | --- |
| Where | Full editor width, just below the caret's line | Anchored at the caret, 760px wide, kept inside the editor |
| Steps | One at a time: Book → Chapter → Verses, with Back in the header (frames `phone-book.png`, `phone-chapter.png`, `phone-verses.png`) | All three side by side: books, chapters, verses (frame `desktop-picker.png`) |
| Buttons | Book rows 48px tall; number buttons 44px, 6 per row | Book rows 34px; number buttons 30px, 7 per row |
| Hints | "Tap a verse, or tap two to choose a range." | "Click two verses for a range · Esc to close", and an Enter hint on the match row |

Styles live in `app/assets/stylesheets/components/_scripture_picker.scss`, BEM (`.scripture-picker`, `__books`, `__grid`, `__number--selected`) and built only from Primer primitives. This is a **fourth approved exception** in `CLAUDE.md`: Primer has no anchored-at-caret picker.

### Typing a reference

- **"+" then a book prefix** ("+p") filters the book list. The first match is highlighted, and Enter or a tap picks it.
- **A chapter and verses** typed after the book ("+ps 37:8-9") are parsed with the same rules as `Bible::Reference.parse`.
  - The picker selects the book, the chapter and the verses.
  - On desktop it shows a match row at the top ("Psalm 37:8, 9 · Psalms, chapter 37, verses 8 to 9", frame `desktop-typed.png`).
  - Enter inserts, replacing the typed "+ps 37:8-9" with the link.
- **Esc** closes the picker and leaves the typed text as it is. So does a click outside, or typing a space after a "+" that matches no book.

### Accessibility

- The picker is a `role="dialog"` with an `aria-label` that changes with the step.
- The book list is a `listbox`. Chapter and verse buttons are real `<button>`s with `aria-pressed`, and the selected range is announced in the footer (`aria-live="polite"`).
- Arrow keys move through the list or grid, and Tab reaches Back, Close, Cancel and Insert.
- In a note, the link's text is the reference, so screen readers read "Psalm 37:8, 9, link". The external icon is hidden from them.

## Reading a note

- Saved notes render scripture attachments through `bible/references/_reference.html.erb`, frames `phone-saved.png` and `desktop-saved.png` (without the hover card, which comes later).
- Shared notes and helper notes render the same way.
- A link opens jw.org in a new tab. jw.org opens JW Library on a phone when it's installed.

## Traps

1. **`attachments: false` blocks scripture links.** Lexxy's `permitsAttachmentContentType` returns false for everything when attachments are off. Use `permitted-attachment-types` instead, and keep uploads off with the `no-uploads` controller and the model validation.
2. **Lexxy is pinned at 1.0.4, and the extension API is experimental.** Upgrade Lexxy only in its own story, and run `test/system/scripture_links_test.rb` first. If `CustomActionTextAttachmentNode`, `contents.replaceTextBackUntil` or `contents.insertAtCursor` change, fix the extension in that story.
3. **Keep the caret.** Save the Lexical selection when the picker opens and restore it inside the `editor.update` that inserts, or the link lands at the start of the note on a phone.
4. **The server signs.** The browser never builds an sgid. `ScripturesController#show` parses the id with `Bible::Reference.find` and 404s on anything invalid.
5. **Strict linking on save.** Only book, chapter and verse ("Matt 24:14"). Never inside code, links or existing attachments, and never a chapter alone. Test the false positives: "Job 5", "Acts of kindness", "John 3" and "1 John".
6. **Abbreviations collide.** No abbreviation in `config/bible.yml` may belong to two books. A test loads the file and checks.
7. **Encrypted notes stay encrypted.** The sgid sits inside the encrypted body like any other content; nothing about the reference is stored in the clear.
8. **No N+1:** rendering a note with many links does no database work per link, since `Bible::Reference.find` is a parse, not a query.

## States each story checks

- **The picker on phone:**
  - books filtered by "+p"
  - a chapter picked
  - one verse
  - two verses (a range)
  - a whole chapter (Insert with no verse chosen)
  - Back and Close
- **The picker on desktop:** all three columns; "+ps 37:8-9" with the match row; Enter inserts; Esc leaves the text.
- **The toolbar button** opens the picker with no query.
- **Saving:**
  - "matt 24:14" becomes "Matthew 24:14"
  - "Job 5" stays text
  - a forged attachment makes the notes invalid
- **Reading:** links render for the author and for a household member reading a shared note.
- **Both editors:** meeting note parts and family study notes.
