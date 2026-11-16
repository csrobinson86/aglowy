require "application_system_test_case"

# The scripture picker from a notes editor's toolbar (docs/design/scripture-links.md, The picker). It's built on
# Lexxy's experimental extension API, so every Lexxy upgrade runs this file first.
class ScriptureLinksTest < ApplicationSystemTestCase
  # Moves the caret to the end of the editor's text: Cmd+Down on a Mac, Ctrl+End on Linux CI.
  END_OF_TEXT = RUBY_PLATFORM.include?("darwin") ? [ :command, :down ] : [ :control, :end ]
  PHONE = { phone: [ 390, 844 ] }
  TALK = "lexxy-editor#meeting_note_parts_attributes_0_notes"
  GEMS = "lexxy-editor#meeting_note_parts_attributes_1_notes"
  PICKER = "[data-controller='scripture-picker']"

  setup do
    sign_in identities(:head)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  # The caret is put mid-text, before " Read", because with no saved selection Lexxy inserts at the end of the note.
  # Before Insert the editor's selection is moved to the start, as a tap on a phone can, so only the saved caret
  # puts the link in the right place (Traps 3).
  test "desktop: Psalms, 37, 8 and 9 go in where the caret was, and save as a link to jw.org" do
    edit_meeting_note
    write_notes TALK, " Read "
    move_caret_back TALK, "Read ".length
    open_picker TALK

    assert_picker "Choose a book"
    assert_accessible
    pick_book "Psalms"
    assert_picker "Choose a chapter of Psalms"
    pick_chapter 37
    assert_picker "Choose verses in Psalm 37"
    pick_verse 8
    pick_verse 9
    assert_reference "Psalm 37:8, 9"
    assert_selector "#{PICKER} [role=listbox]"
    assert_selector "#{PICKER} .scripture-picker__chapters button[aria-pressed=true]", text: "37"
    assert_selector "#{PICKER} .scripture-picker__verses button[aria-pressed=true]", count: 2
    assert_accessible
    capture_screens("scripture-picker-desktop", viewports: ScreenshotHelper::VIEWPORTS.slice(:desktop))
    move_selection_to_start TALK
    click_on "Insert"

    assert_no_selector PICKER
    assert_selector "#{TALK} .scripture-link", text: "Psalm 37:8, 9"
    assert_match(/from a distance\. Psalm 37:8, 9 Read\z/, editor_text(TALK))
    assert_selector "#{TALK} [contenteditable]:focus"
    click_on "Save notes"

    assert_text "Notes saved."
    link = find("main a.scripture-link", text: "Psalm 37:8, 9")
    assert_equal "https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=19037008-19037009", link[:href]
  end

  test "the reference reads as Bible::Reference#to_s does: one tap, a second for a range, a third starts again" do
    edit_meeting_note
    open_picker TALK
    pick_book "Psalms"
    pick_chapter 37

    assert_reference "Psalm 37"
    pick_verse 8
    assert_reference "Psalm 37:8"
    pick_verse 9
    assert_reference "Psalm 37:8, 9"
    pick_verse 11
    assert_reference "Psalm 37:11"
    pick_verse 8
    assert_reference "Psalm 37:8-11"
    assert_selector "#{PICKER} .scripture-picker__verses button[aria-pressed=true]", count: 4
  end

  test "phone: one step at a time, with Back" do
    edit_meeting_note
    use_phone
    write_notes TALK, " Read "
    move_caret_back TALK, "Read ".length
    open_picker TALK

    assert_picker "Choose a book"
    assert_no_selector "#{PICKER} .scripture-picker__chapters"
    assert_no_selector "#{PICKER} button[aria-label=Back]"
    assert_no_button "Insert"
    assert_accessible
    capture_screens("scripture-picker-book", viewports: PHONE)
    use_phone

    pick_book "Psalms"
    assert_picker "Choose a chapter of Psalms"
    assert_no_selector "#{PICKER} [role=listbox]"
    click_picker_button "Back"
    assert_picker "Choose a book"
    pick_book "Psalms"
    pick_chapter 37
    click_picker_button "Back"
    assert_picker "Choose a chapter of Psalms"
    assert_selector "#{PICKER} button[aria-pressed=true]", text: "37"
    assert_accessible
    capture_screens("scripture-picker-chapter", viewports: PHONE)
    use_phone

    pick_chapter 37
    assert_picker "Choose verses in Psalm 37"
    assert_no_selector "#{PICKER} .scripture-picker__chapters"
    assert_text "Tap a verse, or tap two to choose a range."
    pick_verse 8
    pick_verse 9
    assert_reference "Psalm 37:8, 9"
    assert_accessible
    capture_screens("scripture-picker-verses", viewports: PHONE)
    use_phone
    move_selection_to_start TALK
    click_on "Insert"

    assert_no_selector PICKER
    assert_match(/from a distance\. Psalm 37:8, 9 Read\z/, editor_text(TALK))
  end

  test "whole chapter: Insert with no verse gives Psalm 23" do
    edit_meeting_note
    write_notes TALK, " Read "
    open_picker TALK
    pick_book "Psalms"
    pick_chapter 23
    click_on "Insert"

    assert_selector "#{TALK} .scripture-link", text: "Psalm 23"
    click_on "Save notes"

    assert_text "Notes saved."
    assert_equal Bible::Reference.find("19:23").jw_url, find("main a.scripture-link", text: "Psalm 23")[:href]
  end

  test "Cancel, Esc and a phone's Close leave the note unchanged, and Esc puts focus back in the editor" do
    edit_meeting_note
    write_notes TALK, " Read "
    text = editor_text(TALK)

    open_picker TALK
    pick_book "Psalms"
    pick_chapter 37
    click_on "Cancel"
    assert_no_selector PICKER

    open_picker TALK
    pick_book "Psalms"
    pick_chapter 37
    pick_verse 8
    page.send_keys(:escape)
    assert_no_selector PICKER
    assert_selector "#{TALK} [contenteditable]:focus"

    use_phone
    open_picker TALK
    pick_book "Psalms"
    click_picker_button "Close"
    assert_no_selector PICKER

    assert_equal text, editor_text(TALK)
    assert_no_selector "#{TALK} .scripture-link"
  end

  test "a click outside closes the picker" do
    edit_meeting_note
    open_picker TALK
    pick_book "Psalms"
    find("h1").click

    assert_no_selector PICKER
    assert_no_selector "#{TALK} .scripture-link"
  end

  test "family study notes: the same insert works on a session's notes" do
    study_session = family_study_sessions(:one_off_first)
    study_session.update!(notes: "<p>Read chapter 1</p>")
    visit edit_household_family_study_session_notes_url(household_id: households(:home), family_study_id: study_session.family_study, session_id: study_session)
    write_notes "lexxy-editor", " and "
    open_picker "lexxy-editor"
    pick_book "Psalms"
    pick_chapter 37
    pick_verse 8
    pick_verse 9
    click_on "Insert"

    assert_selector "lexxy-editor .scripture-link", text: "Psalm 37:8, 9"
    assert_match(/Read chapter 1 and Psalm 37:8, 9/, editor_text("lexxy-editor"))
    click_on "Save notes"

    assert_text "Notes saved."
    assert_equal Bible::Reference.find("19:37:8-9").jw_url, find("main a.scripture-link", text: "Psalm 37:8, 9")[:href]
  end

  test "late response: pressed Insert, then Esc, then opened in another editor, and nothing is inserted anywhere" do
    edit_meeting_note
    hold_scripture_responses
    open_picker TALK
    pick_book "Psalms"
    pick_chapter 37
    pick_verse 8
    click_on "Insert"

    assert_selector "#{PICKER}[aria-busy=true]"
    assert_button "Insert", disabled: true
    assert_selector "#{PICKER} .scripture-picker__verses button[disabled]", minimum: 1
    assert_selector "#{PICKER} [role=option][aria-disabled=true]", minimum: 1
    page.send_keys(:escape)
    assert_no_selector PICKER
    open_picker GEMS
    assert_picker "Choose a book"
    assert_no_selector "#{PICKER}[aria-busy=true]"
    release_scripture_responses

    assert_no_selector "#{TALK} .scripture-link"
    assert_no_selector "#{GEMS} .scripture-link"
    assert_picker "Choose a book"

    # The picker still works for the editor it's open in now.
    pick_book "Psalms"
    pick_chapter 23
    click_on "Insert"
    assert_selector "#{GEMS} .scripture-link", text: "Psalm 23"
    assert_no_selector "#{TALK} .scripture-link"
  end

  test "an insert is dropped unless it's for the open session, in its editor, and the picker's current reference" do
    edit_meeting_note
    open_picker TALK
    pick_book "Psalms"
    pick_chapter 37
    pick_verse 8
    session = find(PICKER)["data-scripture-picker-session-value"].to_i

    dispatch_insert(session: session - 1, reference: "19:37:8")
    dispatch_insert(session:, reference: "19:23")
    assert_no_selector "lexxy-editor .scripture-link"

    dispatch_insert(session:, reference: "19:37:8", query: "+ps 37:8")
    assert_no_selector "lexxy-editor .scripture-link"

    dispatch_insert(session:, reference: "19:37:8")
    assert_selector "#{TALK} .scripture-link", text: "Psalm 37:8", count: 1
    assert_selector "lexxy-editor .scripture-link", count: 1
  end

  test "desktop: typing +ps 37:8-9 fills the picker, and Enter puts the link in place of the whole query" do
    edit_meeting_note
    assert_selector "#{TALK} button[name=scripture] kbd", text: "+"
    write_notes TALK, " +ps 37:8-9"

    assert_picker "Choose verses in Psalm 37"
    assert_selector "#{PICKER} .scripture-picker__match", text: "Psalm 37:8, 9 · Psalms, chapter 37, verses 8 to 9"
    assert_selector "#{PICKER} .scripture-picker__match kbd", text: "Enter"
    assert_reference "Psalm 37:8, 9"
    assert_selector "#{PICKER} [role=option][aria-selected=true]", text: "Psalms"
    assert_selector "#{PICKER} .scripture-picker__chapters button[aria-pressed=true]", text: "37"
    assert_selector "#{PICKER} .scripture-picker__verses button[aria-pressed=true]", count: 2
    assert_selector "#{TALK} [contenteditable]:focus"
    assert_accessible
    capture_screens("scripture-typed", viewports: ScreenshotHelper::VIEWPORTS.slice(:desktop))
    type_notes TALK, :enter

    assert_no_selector PICKER
    assert_selector "#{TALK} .scripture-link", text: "Psalm 37:8, 9"
    assert_match(/from a distance\. Psalm 37:8, 9\z/, editor_text(TALK))
    assert_no_match(/\+ps/, editor_text(TALK))
    click_on "Save notes"

    assert_text "Notes saved."
    assert_equal "https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=19037008-19037009",
      find("main a.scripture-link", text: "Psalm 37:8, 9")[:href]
  end

  test "+p lists the books it starts, and ArrowDown then Enter picks Proverbs and shows its chapters" do
    edit_meeting_note
    write_notes TALK, " +p"

    assert_picker "Choose a book"
    assert_equal [ "Psalms", "Proverbs", "Philippians", "Philemon", "1 Peter", "2 Peter" ],
      all("#{PICKER} [role=option] .scripture-picker__book-name").map(&:text)
    assert_selector "#{PICKER} .scripture-picker__book--active", text: "Psalms"
    type_notes TALK, :down
    assert_selector "#{PICKER} .scripture-picker__book--active", text: "Proverbs"
    type_notes TALK, :enter

    assert_picker "Choose a chapter of Proverbs"
    assert_selector "#{PICKER} [role=option][aria-selected=true]", text: "Proverbs"
    assert_selector "#{PICKER} .scripture-picker__chapters button", count: 31
    assert_match(/from a distance\. \+p\z/, editor_text(TALK))
  end

  test "Esc after +ps 37 leaves +ps 37 in the note, and Enter goes back to starting a new line" do
    edit_meeting_note
    write_notes TALK, " +ps 37"
    assert_picker "Choose verses in Psalm 37"
    type_notes TALK, :escape

    assert_no_selector PICKER
    assert_match(/from a distance\. \+ps 37\z/, editor_text(TALK))
    assert_selector "#{TALK} [contenteditable]:focus"
    type_notes TALK, ":8", :enter, "Next"

    assert_no_selector PICKER
    assert_no_selector "#{TALK} .scripture-link"
    assert_selector "#{TALK} [contenteditable] p", text: "Next"
    assert_match(/\+ps 37:8\nNext\z/, find("#{TALK} [contenteditable='true']").text)
  end

  test "a space after a + that matches no book, or a click outside, closes the picker and leaves the text" do
    edit_meeting_note
    write_notes TALK, " +xyz"
    assert_selector PICKER
    type_notes TALK, " "
    assert_no_selector PICKER

    type_notes TALK, "+ps"
    assert_selector PICKER
    find("h1").click
    assert_no_selector PICKER
    assert_match(/from a distance\. \+xyz \+ps\z/, editor_text(TALK))
  end

  test "changed while waiting: a lookup for 37:8 that answers after -9 is typed inserts nothing" do
    edit_meeting_note
    hold_scripture_responses
    write_notes TALK, " +ps 37:8"
    assert_reference "Psalm 37:8"
    type_notes TALK, :enter
    assert_selector "#{PICKER}[aria-busy=true]"
    type_notes TALK, "-9"

    assert_reference "Psalm 37:8, 9"
    release_scripture_responses
    assert_no_selector "#{TALK} .scripture-link"
    assert_reference "Psalm 37:8, 9"
    assert_selector "#{PICKER} .scripture-picker__verses button[aria-pressed=true]", count: 2
    assert_match(/\+ps 37:8-9\z/, editor_text(TALK))

    type_notes TALK, :enter
    assert_selector "#{TALK} .scripture-link", text: "Psalm 37:8, 9", count: 1
    assert_no_match(/\+ps/, editor_text(TALK))
  end

  test "a + in the middle of a word, as in 2+2, doesn't open the picker" do
    edit_meeting_note
    write_notes TALK, " 2+2"
    assert_no_selector PICKER
    type_notes TALK, " word+p"
    assert_no_selector PICKER

    type_notes TALK, " +p"
    assert_picker "Choose a book"
  end

  test "phone: +p, then tapping through to Insert, works as the toolbar does" do
    edit_meeting_note
    use_phone
    assert_no_selector "#{TALK} button[name=scripture] kbd"
    write_notes TALK, " +p"

    assert_picker "Choose a book"
    assert_selector "#{PICKER} [role=option]", count: 6
    assert_no_selector "#{PICKER} .scripture-picker__match"
    assert_accessible
    capture_screens("scripture-typed-book", viewports: PHONE)
    use_phone
    pick_book "Psalms"
    pick_chapter 37
    pick_verse 8
    pick_verse 9
    click_on "Insert"

    assert_no_selector PICKER
    assert_selector "#{TALK} .scripture-link", text: "Psalm 37:8, 9"
    assert_match(/from a distance\. Psalm 37:8, 9\z/, editor_text(TALK))
    assert_no_match(/\+p/, editor_text(TALK))
  end

  test "phone: +ps 37 typed, then verses 8 and 9 tapped, replaces the whole query because the caret followed it" do
    edit_meeting_note
    use_phone
    write_notes TALK, " +ps 37"

    assert_picker "Choose verses in Psalm 37"
    pick_verse 8
    pick_verse 9
    click_on "Insert"

    assert_no_selector PICKER
    assert_selector "#{TALK} .scripture-link", text: "Psalm 37:8, 9"
    assert_match(/from a distance\. Psalm 37:8, 9\z/, editor_text(TALK))
    assert_no_match(/\+ps 37/, editor_text(TALK))
  end

  private
    def edit_meeting_note
      visit edit_household_meeting_note_url(household_id: households(:home), id: meeting_notes(:head_midweek))
      assert_selector "lexxy-toolbar button[name=scripture]", minimum: 2
      assert_selector PICKER, count: 1, visible: :hidden
    end

    # Types into the editor the way a person does: focus it, then type at its end.
    def write_notes(editor, text)
      editable = find("#{editor} [contenteditable='true']")
      editable.click
      editable.send_keys(END_OF_TEXT, text)
    end

    # Types where the editor's caret already is.
    def type_notes(editor, *keys)
      find("#{editor} [contenteditable='true']").send_keys(*keys)
    end

    def move_caret_back(editor, characters)
      find("#{editor} [contenteditable='true']").send_keys(*[ :left ] * characters)
    end

    # Moves the editor's own selection to the start of its text while the picker is open. Lexical follows the
    # browser's selection, so without the session's saved caret the link would land there.
    def move_selection_to_start(editor)
      page.evaluate_async_script(<<~JS, "#{editor} [contenteditable='true']")
        const [ selector, done ] = arguments
        const editable = document.querySelector(selector)
        editable.focus()
        getSelection().collapse(document.createTreeWalker(editable, NodeFilter.SHOW_TEXT).nextNode(), 0)
        requestAnimationFrame(() => requestAnimationFrame(done))
      JS
      assert_selector PICKER
    end

    def open_picker(editor)
      find("#{editor} lexxy-toolbar button[name=scripture]").click
      assert_selector PICKER
    end

    def editor_text(editor)
      find("#{editor} [contenteditable='true']").text.squish
    end

    # Back and Close are icon buttons, named by their aria-label.
    def click_picker_button(label)
      find("#{PICKER} button[aria-label='#{label}']").click
    end

    def assert_picker(label)
      assert_selector "#{PICKER}[role=dialog][aria-label='#{label}']"
    end

    def assert_reference(text)
      assert_selector "#{PICKER} [aria-live=polite]", exact_text: text
    end

    def pick_book(name)
      find("#{PICKER} [role=option]", text: /\A#{name}\b/).click
    end

    def pick_chapter(number)
      within("#{PICKER} .scripture-picker__chapters") { click_on number.to_s }
    end

    def pick_verse(number)
      within("#{PICKER} .scripture-picker__verses") { click_on number.to_s }
    end

    # The phone frames' size, with touch, as the screenshots use. The teardown puts the desktop back after it.
    def use_phone
      emulate_viewport(*PHONE[:phone], phone: true)
      emulate_touch(true)
    end

    # The picker's lookups wait until release_scripture_responses, and arrive even if they were aborted, as a
    # response already on its way would. Releasing them puts fetch back.
    def hold_scripture_responses
      page.execute_script(<<~JS)
        const fetch = window.unheldFetch = window.fetch
        window.heldScriptureResponses = []
        window.fetch = (url, options) => new Promise(resolve => window.heldScriptureResponses.push(() => {
          const response = fetch(url, { headers: options.headers })
          resolve(response)
          return response
        }))
      JS
    end

    def release_scripture_responses
      page.evaluate_async_script(<<~JS)
        const done = arguments[0]
        window.fetch = window.unheldFetch
        Promise.all(window.heldScriptureResponses.map(release => release())).then(() => setTimeout(done, 250))
      JS
    end

    # What the picker sends when a lookup comes back, with a real sgid from the server.
    def dispatch_insert(session:, reference:, query: "")
      page.evaluate_async_script(<<~JS, session, reference, query)
        const [ session, reference, query, done ] = arguments
        fetch(`/scriptures/${reference}`, { headers: { Accept: "application/json" } }).then(response => response.json()).then(({ sgid, html }) => {
          document.querySelector("#{PICKER}").dispatchEvent(new CustomEvent("scripture-picker:insert", { bubbles: true, detail: { session, sgid, html, reference, query } }))
          setTimeout(done, 100)
        })
      JS
    end
end
