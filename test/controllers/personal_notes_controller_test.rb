require "test_helper"

class PersonalNotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @note = personal_notes(:head_daniel)
  end

  test "index lists my notes as cards, my collections for notes, and my tags" do
    @note.body = "<p>Head of gold, chest of silver. Read Daniel 2:31-33 and Daniel 2:44</p>"
    @note.link_scriptures
    @note.save!
    @note.tag_with("ministry", by: users(:head))
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home)

    assert_response :success
    assert_select "title", "Notes · The Head Family · Aglowy"
    assert_select "h1", "Notes"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Notes"
    assert_select "main .note-card", count: 3
    assert_select "main", text: /Comfort for someone grieving/, count: 0
    assert_select "main .note-card", text: /Daniel 2 image: quick reference/ do |card|
      assert_select card, "a[href=?]", household_personal_note_path(household_id: @home, id: @note), text: @note.title
      assert_select card, ".note-card__preview", text: /Head of gold, chest of silver/
      assert_select card, "a.Label[href=?]", household_tag_path(household_id: @home, name: "ministry"), text: "#ministry"
      assert_select card, ".note-card__meta", text: /Quick references · 2 scriptures · /
    end
    assert_select "main .note-card", text: /Ideas for family worship/ do |card|
      assert_select card, ".note-card__meta", text: /No collection · /
    end
    assert_select "nav[aria-label='Collections'] a[aria-current='page']", text: /All notes\s+3/
    assert_select "nav[aria-label='Collections'] a", text: /Bible questions/ do |link|
      assert_select link, "svg[aria-label='Shared with Personal study']"
    end
    assert_select "nav[aria-label='Collections'] a", text: /Quick references\s+1/
    assert_select "nav[aria-label='Collections'] a", text: /Preparing a talk/, count: 0
    assert_select "main", text: /Also used in Personal study/
    assert_select "button", text: /New collection/
    assert_select "nav[aria-label='My tags'] a[href=?]", household_personal_notes_path(household_id: @home, tag: "ministry"), text: /#ministry\s+2/
    assert_select "input[type=search][placeholder='Search titles, collections and tags']"
  end

  test "the header is followed by the Notes tabs, with Notes selected" do
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home)

    assert_select "main .Subhead + nav[aria-label='Notes, meeting notes and bookmarks']"
    assert_select "main nav[aria-label='Notes, meeting notes and bookmarks'] a[aria-current='page'][href=?]", household_personal_notes_path(household_id: @home), text: /Notes\s+3/
    assert_select "main nav[aria-label='Notes, meeting notes and bookmarks'] a[href=?]", household_meeting_notes_path(household_id: @home), text: /Meeting notes\s+2/
  end

  test "Pinned, newest pin first, then All notes; pinned cards carry an Unpin button" do
    travel_to(1.day.ago) { @note.pin_to_top }
    personal_notes(:head_return_visit).pin_to_top
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home)

    assert_select "main section[aria-labelledby] h2", text: /\A(Pinned|All notes)\z/ do |headings|
      assert_equal [ "Pinned", "All notes" ], headings.map { it.text.strip }
    end
    assert_select "section[aria-labelledby=pinned-notes] .note-card", count: 2 do |cards|
      assert_match "Questions for my return visit", cards.first.text
      assert_match "Daniel 2 image: quick reference", cards.last.text
    end
    assert_select "section[aria-labelledby=pinned-notes] .note-card", text: /Daniel 2 image/ do |card|
      assert_select card, "form[action=?] input[name=_method][value=delete]", household_personal_note_pin_path(household_id: @home, personal_note_id: @note)
      assert_select card, "form button[type=submit][name=from][value=list][aria-pressed=true]", "Unpin"
    end
    assert_select "section[aria-labelledby=all-notes] .note-card", count: 1
    assert_select "section[aria-labelledby=all-notes] .note-card", text: /Ideas for family worship/ do |card|
      assert_select card, "button[aria-pressed]", count: 0
    end
  end

  test "filters narrow the pinned notes too, and with none pinned there's no Pinned" do
    @note.pin_to_top
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home, color: "green")

    assert_select "section[aria-labelledby=pinned-notes]", count: 0
    assert_select "section[aria-labelledby=all-notes] .note-card", count: 1

    get household_personal_notes_path(household_id: @home, color: "orange")

    assert_select "section[aria-labelledby=pinned-notes] .note-card", count: 1
    assert_select "section[aria-labelledby=all-notes]", count: 0
    assert_select ".blankslate", count: 0
  end

  test "the New collection dialog on Notes offers Notes and Personal study, or Notes only" do
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home)

    assert_select "dialog#new-collection-dialog" do
      assert_select "input[type=radio][value=both][checked]"
      assert_select "label", text: "Notes and Personal study"
      assert_select "label", text: "Notes only"
      assert_select "input[type=radio][value=notes]"
      assert_select "input[type=radio][value=studies]", count: 0
      assert_select "input[type=hidden][name=section][value=notes]"
    end
  end

  test "a collection created on Notes goes back to Notes, filtered to it" do
    sign_in identities(:head)

    post household_collections_path(household_id: @home), params: { section: "notes", collection: { name: "Convention 2027", used_in: "notes" } }

    collection = users(:head).collections.find_by!(name: "Convention 2027")
    assert collection.used_in_notes?
    assert_redirected_to household_personal_notes_path(household_id: @home, collection: collection.id)
  end

  test "index with no notes shows the empty state" do
    sign_in identities(:eli)

    get household_personal_notes_path(household_id: @home)

    assert_select ".blankslate h2", "No notes yet."
    assert_select ".blankslate p", "Write one to come back to."
    assert_select ".blankslate a[href=?]", new_household_personal_note_path(household_id: @home), text: "New note"
  end

  test "filters by collection" do
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home, collection: collections(:head_quick_references).id)

    assert_select "main .note-card", count: 1
    assert_select "main .note-card", text: /Daniel 2 image/
    assert_select "nav[aria-label='Collections'] a[aria-current='page']", text: /Quick references/
  end

  test "the phone's menu is named for the collection showing, and holds the collections and tags, the ones showing current" do
    @note.tag_with("ministry", by: users(:head))
    sign_in identities(:head)
    quick_references = collections(:head_quick_references)

    get household_personal_notes_path(household_id: @home)
    assert_select "action-menu button", text: "All notes"
    assert_select "action-menu a[aria-current=true]", count: 1, text: "All notes"

    get household_personal_notes_path(household_id: @home, collection: quick_references.id, tag: "ministry")
    assert_select "action-menu button", text: "Quick references"
    assert_select "action-menu a[aria-current=true]", count: 2
    assert_select "action-menu li.ActionListItem--navActive a[aria-current=true][href=?]", household_personal_notes_path(household_id: @home, collection: quick_references.id, tag: "ministry"), text: "Quick references"
    assert_select "action-menu li.ActionListItem--navActive a[aria-current=true][href=?]", household_personal_notes_path(household_id: @home, tag: "ministry", collection: quick_references.id), text: "#ministry"
    assert_select "action-menu a:not([aria-current])[href=?]", household_personal_notes_path(household_id: @home, tag: "ministry"), text: "All notes"
    assert_select "action-menu a[href=?]", household_personal_notes_path(household_id: @home, collection: collections(:head_bible_questions).id, tag: "ministry"), text: "Bible questions"
    assert_select "action-menu a", text: "Preparing a talk", count: 0
  end

  test "filtered by another person's collection, or a studies-only one, shows nothing" do
    sign_in identities(:head)

    [ collections(:spouse_ministry), collections(:head_talks) ].each do |collection|
      get household_personal_notes_path(household_id: @home, collection: collection.id)

      assert_select "main .note-card", count: 0
      assert_select ".blankslate h2", "No notes match"
    end
  end

  test "filters by tag" do
    personal_notes(:head_family_worship).tag_with("talk-prep", by: users(:head))
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home, tag: "Talk Prep")

    assert_select "main .note-card", count: 1
    assert_select "main .note-card", text: /Ideas for family worship/
    assert_select "a[aria-label='Remove filter #talk-prep'][href=?]", household_personal_notes_path(household_id: @home)
    assert_select "nav[aria-label='My tags'] a[aria-current='page']", text: /#talk-prep/
  end

  test "filters by q, together with a collection" do
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home, q: "return")
    assert_select "main .note-card", count: 1
    assert_select "main .note-card", text: /Questions for my return visit/
    assert_select "input[name=q][value=return]"

    get household_personal_notes_path(household_id: @home, q: "return", collection: collections(:head_quick_references).id)
    assert_select "main .note-card", count: 0
    assert_select "input[type=hidden][name=collection][value=?]", collections(:head_quick_references).id
  end

  test "?color=green lists only green notes, with Only green notes pressed" do
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home, color: "green")

    assert_select "main .note-card", count: 1
    assert_select "main .note-card.note-card--green", text: /Questions for my return visit/ do |card|
      assert_select card, ".sr-only", "Green note"
    end
    assert_select "button[name=color][value=green][aria-pressed=true]", "Only green notes"
    assert_select "button[name=color][value=''][aria-pressed=false]", "Any color"
    assert_select "button[aria-pressed=true]", count: 1
  end

  test "?color=teal is ignored" do
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home, color: "teal")

    assert_select "main .note-card", count: 3
    assert_select "main .note-card.note-card--orange", text: /Daniel 2 image/
    assert_select "main .note-card.note-card--none", text: /Ideas for family worship/ do |card|
      assert_select card, ".sr-only", text: /note\z/, count: 0
    end
    assert_select "main [class*=teal]", count: 0
    assert_select "button[name=color][value=''][aria-pressed=true]", "Any color"
  end

  test "?color=brown lists only brown notes, and the filter offers red, brown and gray" do
    personal_notes(:head_family_worship).update!(color: "brown")
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home, color: "brown")

    assert_select "main .note-card", count: 1
    assert_select "main .note-card.note-card--brown", text: /Ideas for family worship/ do |card|
      assert_select card, ".sr-only", "Brown note"
    end
    assert_select "button[name=color][value=brown][aria-pressed=true]", "Only brown notes"
    assert_select "button[name=color][value=red].note-color-filter__button--red", "Only red notes"
    assert_select "button[name=color][value=gray].note-color-filter__button--gray", "Only gray notes"
    assert_equal PersonalNote::FILTER_COLORS, css_select("button[name=color]").map { it["value"] }.compact_blank
  end

  test "the color filter keeps the collection, tag and search, and they keep the color" do
    sign_in identities(:head)

    get household_personal_notes_path(household_id: @home, color: "orange", q: "daniel", collection: collections(:head_quick_references).id, tag: "ministry")

    assert_select "form:has(button[name=color])" do
      assert_select "input[type=hidden][name=q][value=daniel]"
      assert_select "input[type=hidden][name=collection][value=?]", collections(:head_quick_references).id
      assert_select "input[type=hidden][name=tag][value=ministry]"
    end
    assert_select "form:has(input[name=q][type=search]) input[type=hidden][name=color][value=orange]"
  end

  test "new, with the collection I was looking at chosen" do
    sign_in identities(:head)

    get new_household_personal_note_path(household_id: @home, collection: collections(:head_quick_references).id)

    assert_response :success
    assert_select "h1", "New note"
    assert_select "select[name='personal_note[collection_id]'] option[selected][value=?]", collections(:head_quick_references).id
    assert_select "select[name='personal_note[collection_id]'] option", text: "None"
    assert_select "select[name='personal_note[collection_id]'] option", text: "Preparing a talk", count: 0
    assert_select "lexxy-editor[name='personal_note[body]']"
    assert_select "button[type=submit]", "Save note"
  end

  test "new draws the form inside a note card with no color" do
    sign_in identities(:head)

    get new_household_personal_note_path(household_id: @home)

    assert_select "main .note-card.note-card--none form[action=?]", household_personal_notes_path(household_id: @home) do
      assert_select "input[type=radio][name='personal_note[color]'][value=none][checked]"
      assert_select "button[type=submit]", "Save note"
    end
    assert_select "main .note-card", count: 1
    assert_select "main .note-card [data-note-color-name]", count: 0
    assert_select "main .Box", count: 0
  end

  test "a refused create with Red draws the card red, with Red still chosen" do
    sign_in identities(:head)

    assert_no_difference -> { PersonalNote.count } do
      post household_personal_notes_path(household_id: @home), params: { personal_note: { title: " ", color: "red" } }
    end
    assert_response :unprocessable_content
    assert_select "main .note-card.note-card--red" do
      assert_select "input[type=radio][name='personal_note[color]'][value=red][checked]"
      assert_select ".color-picker__chosen", "Red"
      assert_select ".sr-only[data-note-color-name]", "Red note"
    end
  end

  test "new with a title fills the title field, and saves nothing" do
    sign_in identities(:head)

    assert_no_difference(-> { PersonalNote.count }) do
      get new_household_personal_note_path(household_id: @home, title: "Tuesday, November 17")
    end

    assert_response :success
    assert_select "input[name='personal_note[title]'][value=?]", "Tuesday, November 17"
  end

  test "new without a title leaves the title field empty, as before" do
    sign_in identities(:head)

    get new_household_personal_note_path(household_id: @home)

    assert_select "input[name='personal_note[title]']"
    assert_select "input[name='personal_note[title]'][value]", count: 0
  end

  test "create a note in a collection, with a scripture reference linked on save" do
    sign_in identities(:head)

    assert_difference -> { users(:head).personal_notes.count } do
      post household_personal_notes_path(household_id: @home),
           params: { personal_note: { title: "Prayer", collection_id: collections(:head_bible_questions).id, body: "<p>Read Philippians 4:6</p>" } }
    end

    note = users(:head).personal_notes.find_by!(title: "Prayer")
    assert_redirected_to household_personal_note_path(household_id: @home, id: note)
    assert_equal "Note saved.", flash[:notice]
    assert_equal collections(:head_bible_questions), note.collection
    assert_equal [ Bible::Reference.find("50:4:6") ], note.body.body.attachables
  end

  test "create without a collection, and a blank title shows the form again" do
    sign_in identities(:head)

    post household_personal_notes_path(household_id: @home), params: { personal_note: { title: "Prayer", collection_id: "" } }
    assert_nil users(:head).personal_notes.find_by!(title: "Prayer").collection

    assert_no_difference -> { PersonalNote.count } do
      post household_personal_notes_path(household_id: @home), params: { personal_note: { title: " ", body: "<p>Kept</p>" } }
    end
    assert_response :unprocessable_content
    assert_select "h1", "New note"
    assert_select "lexxy-editor[value*=Kept]"
  end

  test "create in a studies-only collection shows the form again" do
    sign_in identities(:head)

    assert_no_difference -> { PersonalNote.count } do
      post household_personal_notes_path(household_id: @home), params: { personal_note: { title: "Prayer", collection_id: collections(:head_talks).id } }
    end
    assert_response :unprocessable_content
    assert_select "main", text: /Collection is only used in Personal study/
  end

  # docs/design/notes.md, A note: Tags on a new note.
  test "new has the tag editor under the form in the note card, with the form sending its names" do
    sign_in identities(:head)

    get new_household_personal_note_path(household_id: @home)

    assert_select "main .note-card" do
      assert_select "form[action=?][data-controller=note-tag-names][data-note-tag-names-editor-value=tag_editor_personal_note]", household_personal_notes_path(household_id: @home)
      assert_select "form + div #tag_editor_personal_note[data-tag-editor-current-value='[]']" do
        assert_select "input[name=name][placeholder='Add a tag']"
      end
    end
    assert_select "form[action*=taggings]", count: 0
  end

  test "create with tag_names[] tags the note, with Talk Prep as one tag" do
    sign_in identities(:head)

    assert_difference -> { users(:head).personal_notes.count } => 1, -> { Tagging.count } => 2 do
      post household_personal_notes_path(household_id: @home), params: { personal_note: { title: "Talks", tag_names: [ "Talk Prep", "Ministry" ] } }
    end

    note = users(:head).personal_notes.find_by!(title: "Talks")
    assert_redirected_to household_personal_note_path(household_id: @home, id: note)
    assert_equal %w[ ministry talk-prep ], note.tags.map(&:name).sort
    assert_includes note.tags, tags(:head_ministry)
  end

  test "a refused tag re-renders new with the error and keeps the names" do
    sign_in identities(:head)

    assert_no_difference -> { PersonalNote.count } => 0, -> { Tag.count } => 0, -> { Tagging.count } => 0 do
      post household_personal_notes_path(household_id: @home), params: { personal_note: { title: "Talks", body: "<p>Kept</p>", tag_names: [ "Talk Prep", "###" ] } }
    end

    assert_response :unprocessable_content
    assert_select "h1", "New note"
    assert_select ".Banner--error", text: %(Couldn't add the tag "###": Name needs at least one letter or number)
    assert_select "input[name='personal_note[title]'][value=Talks]"
    assert_select "lexxy-editor[value*=Kept]"
    assert_select "#tag_editor_personal_note[data-tag-editor-current-value=?]", [ "Talk Prep", "###" ].to_json do
      assert_select "span.Label", text: "#Talk Prep"
      assert_select "span.Label", text: "####"
      assert_select "button[type=button][aria-label='Remove tag Talk Prep']"
    end
  end

  test "update ignores tag_names" do
    sign_in identities(:head)

    assert_no_difference -> { Tag.count } => 0, -> { Tagging.count } => 0 do
      patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: base(@note), title: "Daniel 2", tag_names: [ "prayer" ] } }
    end

    assert_redirected_to household_personal_note_path(household_id: @home, id: @note)
    assert_equal "Daniel 2", @note.reload.title
    assert_empty @note.tags
  end

  test "show is the read view: the title, color, collection and tags, the body as saved, and no form fields" do
    @note.body = "<h2>Statue</h2><p>Daniel 2:44, then Daniel 2:31-33, then Daniel 2:44 again</p>"
    @note.link_scriptures
    @note.save!
    @note.tag_with("ministry", by: users(:head))
    sign_in identities(:head)

    get household_personal_note_path(household_id: @home, id: @note)

    assert_response :success
    assert_select "title", "#{@note.title} · The Head Family · Aglowy"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Notes"
    assert_select "nav[aria-label='Breadcrumb'] a", text: "Notes"
    assert_select "nav[aria-label='Breadcrumb'] a[href=?]", household_personal_notes_path(household_id: @home, collection: collections(:head_quick_references).id), text: "Quick references"
    assert_select "a.Button[href=?]", edit_household_personal_note_path(household_id: @home, id: @note), text: "Edit"
    assert_select "#pin_personal_note_#{@note.id} form[action=?] button[type=submit][aria-pressed=false]",
                  household_personal_note_pin_path(household_id: @home, personal_note_id: @note), text: "Pin"
    assert_select "main .note-card.note-card--orange" do
      assert_select "h1", @note.title
      assert_select ".note-dot--orange + *", "Orange"
      assert_select "a[href=?]", household_personal_notes_path(household_id: @home, collection: collections(:head_quick_references).id), text: "Quick references"
      assert_select "a.Label[href=?]", household_tag_path(household_id: @home, name: "ministry"), text: "#ministry"
      assert_select ".lexxy-content h2", "Statue"
      assert_select ".lexxy-content a.scripture-link", count: 3
    end
    assert_select "main input:not([type=hidden]), main select, main textarea, main lexxy-editor", count: 0
    assert_select "main form input[name=_method][value=patch]", count: 0
    assert_select "#tag_editor_personal_note_#{@note.id}", count: 0
    assert_select "section[aria-labelledby=note-scriptures]" do
      assert_select "a.scripture-link" do |links|
        assert_equal [ "Daniel 2:44", "Daniel 2:31-33" ], links.map { it.text.strip }
      end
      assert_select "*", text: /Each opens on jw.org, or in JW Library if it's installed./
    end
    assert_select "section[aria-labelledby=note-details]", text: /Created/
    assert_select "dialog#delete-personal-note"
  end

  test "show escapes the title, collection and tags, and a note with no color or collection shows neither" do
    note = personal_notes(:head_family_worship)
    note.update!(title: "<b>Bold</b> plans")
    sign_in identities(:head)

    get household_personal_note_path(household_id: @home, id: note)

    assert_select "main h1", "<b>Bold</b> plans"
    assert_select "main h1 b", count: 0
    assert_select "main .note-card.note-card--none .note-dot", count: 0
    assert_select "main .note-card a[href*=collection]", count: 0
  end

  test "edit opens today's form with the version check's base, Cancel back to the read view, and the tag editor" do
    @note.tag_with("ministry", by: users(:head))
    sign_in identities(:head)

    get edit_household_personal_note_path(household_id: @home, id: @note)

    assert_response :success
    assert_select "title", "#{@note.title} · The Head Family · Aglowy"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Notes"
    assert_select "nav[aria-label='Breadcrumb'] a[href=?]", household_personal_notes_path(household_id: @home, collection: collections(:head_quick_references).id), text: "Quick references"
    assert_select "a.Button", text: "Edit", count: 0
    assert_select "#pin_personal_note_#{@note.id} button[type=submit]", "Pin"
    assert_select "main .note-card.note-card--orange form[action=?][data-controller=note-tag-names]", household_personal_note_path(household_id: @home, id: @note) do
      assert_select "input[type=hidden][name='personal_note[base]'][value=?]", @note.reload.updated_at.utc.iso8601(6)
      assert_select "input[name^='personal_note[tag_names]']", count: 0
      assert_select "input[name='personal_note[title]'][value=?]", @note.title
      assert_select "select[name='personal_note[collection_id]'] option[selected]", text: "Quick references"
      assert_select "fieldset legend", "Color"
      assert_select "input[type=radio][name='personal_note[color]'][value=orange][checked]"
      assert_select "lexxy-editor[name='personal_note[body]']"
      assert_select "button[type=submit]", "Save note"
      assert_select "a.Button[href=?]", household_personal_note_path(household_id: @home, id: @note), text: "Cancel"
    end
    assert_select "main", text: /Saved/
    assert_select "main .note-card.note-card--orange .sr-only", "Orange note"
    assert_select "#tag_editor_personal_note_#{@note.id} a.Label", "#ministry"
    assert_select "section[aria-labelledby=note-scriptures]"
    assert_select "section[aria-labelledby=note-details]"
  end

  # docs/design/bookmarks.md, The bookmark button: beside each scripture in Scriptures in this note, filled where it's
  # saved, from one read of the bookmarks.
  test "show: a bookmark button beside each scripture in the note" do
    @note.body = "<p>Daniel 2:44, then Daniel 2:31-33</p>"
    @note.link_scriptures
    @note.save!
    users(:head).bookmark(scripture: "27:2:44", source: @note)
    sign_in identities(:head)

    assert_queries_match(/FROM "bookmarks"/, count: 1) do
      get household_personal_note_path(household_id: @home, id: @note)
    end

    assert_select "section[aria-labelledby=note-scriptures]" do
      assert_select "button[aria-pressed=true][aria-label=?]", "Remove bookmark: Daniel 2:44"
      assert_select "button[aria-pressed=false][aria-label=?]", "Bookmark: Daniel 2:31-33"
      assert_select "input[name=source_type][value=PersonalNote]"
    end
  end

  test "a pinned note's page shows Pinned, pressed" do
    @note.pin_to_top
    sign_in identities(:head)

    get household_personal_note_path(household_id: @home, id: @note)

    assert_select "#pin_personal_note_#{@note.id} button[type=submit][aria-pressed=true]", "Pinned"
    assert_select "#pin_personal_note_#{@note.id} [name=from]", count: 0
  end

  test "update: title, body, and move to another collection and out of any, each back to the read view" do
    sign_in identities(:head)

    patch household_personal_note_path(household_id: @home, id: @note),
          params: { personal_note: { base: base(@note), title: "Daniel 2", collection_id: collections(:head_bible_questions).id, body: "<p>Read Daniel 2:44</p>" } }

    assert_redirected_to household_personal_note_path(household_id: @home, id: @note)
    assert_equal "Note saved.", flash[:notice]
    @note.reload
    assert_equal "Daniel 2", @note.title
    assert_equal collections(:head_bible_questions), @note.collection
    assert_equal [ Bible::Reference.find("27:2:44") ], @note.body.body.attachables

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: base(@note), collection_id: "" } }
    assert_nil @note.reload.collection

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: base(@note), color: "purple" } }
    assert_redirected_to household_personal_note_path(household_id: @home, id: @note)
    assert @note.reload.color_purple?
  end

  test "update: a color outside the list shows the form again" do
    sign_in identities(:head)

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: base(@note), color: "teal" } }

    assert_response :unprocessable_content
    assert_select "main", text: /Color is not included in the list/
    assert @note.reload.color_orange?
    assert_select "main .note-card.note-card--orange"
  end

  test "update: a failed update re-renders edit with the error; a title too long, or a body with more than scripture links" do
    sign_in identities(:head)

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: base(@note), title: "x" * 121 } }
    assert_response :unprocessable_content
    assert_select ".Banner--error", text: /Title is too long/
    assert_select "form[action=?] input[name='personal_note[title]']", household_personal_note_path(household_id: @home, id: @note)
    assert_select "input[type=hidden][name='personal_note[base]'][value=?]", base(@note)
    assert_select "a.Button", text: "Cancel"
    assert_select "h2", text: "What you wrote", count: 0

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: base(@note), body: "<p>A cat</p>#{remote_image_attachment}" } }
    assert_response :unprocessable_content
    assert_nil @note.reload.body.body
  end

  # docs/design/notes.md, A note: the version check. The other window saved since this form was rendered.
  test "update with a stale base: a 409 that writes nothing, the note as it is now with the Banner, and What you wrote" do
    @note.tag_with("ministry", by: users(:head))
    stale = base(@note)
    travel(1.minute) { PersonalNote.find(@note.id).update!(title: "Saved in the other window", color: "green", body: "<p>Theirs</p>") }
    sign_in identities(:head)

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: {
      base: stale, title: "<i>Mine</i>", color: "blue", collection_id: collections(:head_bible_questions).id,
      tag_names: [ "ministry", "Talk Prep" ], body: "<h2>My heading</h2><ul><li>My point</li></ul><script>alert(1)</script>"
    } }

    assert_response :conflict
    @note.reload
    assert_equal "Saved in the other window", @note.title
    assert @note.color_green?
    assert_equal collections(:head_quick_references), @note.collection
    assert_equal "Theirs", @note.body.to_plain_text.strip
    assert_select ".Banner--warning", text: "This note changed after you started editing, so your changes weren't saved. It's shown as it is now. What you wrote is below."
    assert_select "main .note-card.note-card--green form[action=?]", household_personal_note_path(household_id: @home, id: @note) do
      assert_select "input[type=hidden][name='personal_note[base]'][value=?]", @note.updated_at.utc.iso8601(6)
      assert_select "input[name='personal_note[title]'][value=?]", "Saved in the other window"
      assert_select "input[type=radio][name='personal_note[color]'][value=green][checked]"
      assert_select "select[name='personal_note[collection_id]'] option[selected]", text: "Quick references"
      assert_select "lexxy-editor[name='personal_note[body]'][value*=Theirs]"
    end
    assert_select "section[aria-labelledby=what-you-wrote]" do
      assert_select "h2#what-you-wrote", "What you wrote"
      assert_select "*", text: "<i>Mine</i>"
      assert_select "i", count: 0
      assert_select ".note-dot--blue + *", "Blue"
      assert_select "*", text: "Bible questions"
      assert_select ".Label", text: "#ministry"
      assert_select ".Label", text: "#Talk Prep"
      assert_select ".Label", text: "#Talk", count: 0
      assert_select ".lexxy-content h2", "My heading"
      assert_select ".lexxy-content li", "My point"
      assert_select "script", count: 0
      assert_select "clipboard-copy[aria-label='Copy text']" do |copy|
        assert_match(/My heading.*My point/m, copy.first["value"])
      end
      assert_select "input, select, textarea, lexxy-editor", count: 0
    end
  end

  test "a stale update writes no tags, and a blank or unknown color in What you wrote isn't drawn" do
    stale = base(@note)
    travel(1.minute) { PersonalNote.find(@note.id).update!(title: "Saved in the other window") }
    sign_in identities(:head)

    assert_no_difference -> { Tagging.count } do
      assert_no_difference -> { Tag.count } do
        patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: stale, title: "Mine", color: "teal", tag_names: [ "brand-new" ] } }
      end
    end

    assert_response :conflict
    assert_empty @note.reload.tags
    assert_select "section[aria-labelledby=what-you-wrote]" do
      assert_select ".Label", text: "#brand-new"
      assert_select "[class*=teal]", count: 0
      assert_select "clipboard-copy", count: 0
    end
  end

  test "a stale update whose collection was deleted meanwhile is still a 409 with What you wrote; a fresh one is a 404" do
    gone = users(:head).collections.add(name: "Gone", used_in: "notes")
    stale = base(@note)
    travel(1.minute) do
      PersonalNote.find(@note.id).update!(title: "Saved in the other window")
      gone.destroy!
    end
    sign_in identities(:head)

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: stale, title: "Mine", collection_id: gone.id, body: "<p>My point</p>" } }

    assert_response :conflict
    assert_equal "Saved in the other window", @note.reload.title
    assert_equal collections(:head_quick_references), @note.collection
    assert_select "section[aria-labelledby=what-you-wrote]" do
      assert_select "*", text: "Mine"
      assert_select ".lexxy-content", text: /My point/
    end

    sign_in identities(:head)
    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: base(@note), title: "Mine", collection_id: gone.id } }
    assert_response :not_found
    assert_equal "Saved in the other window", @note.reload.title
  end

  test "a note changed and its collection deleted while the update runs is still a 409 with What you wrote" do
    gone = users(:head).collections.add(name: "Gone", used_in: "notes")
    fresh = base(@note)
    sign_in identities(:head)
    # Right after the update loads the note, still at the form's base, another window saves it and deletes the collection.
    meanwhile = lambda do |*, payload|
      next unless payload[:sql].start_with?('SELECT "personal_notes"') && gone.persisted?

      PersonalNote.where(id: @note).update_all(title: "Saved in the other window", updated_at: 1.minute.from_now)
      gone.destroy!
    end

    ActiveSupport::Notifications.subscribed(meanwhile, "sql.active_record") do
      patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: fresh, title: "Mine", collection_id: gone.id } }
    end

    assert_response :conflict
    assert_equal "Saved in the other window", @note.reload.title
    assert_select "section[aria-labelledby=what-you-wrote]", text: /Mine/
  end

  test "update without a base is refused as stale" do
    sign_in identities(:head)

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { title: "No base" } }

    assert_response :conflict
    assert_equal "Daniel 2 image: quick reference", @note.reload.title
  end

  test "destroy" do
    sign_in identities(:head)

    assert_difference -> { PersonalNote.count }, -1 do
      delete household_personal_note_path(household_id: @home, id: @note)
    end
    assert_redirected_to household_personal_notes_path(household_id: @home)
    assert_equal "Note deleted.", flash[:notice]
  end

  test "another person's note: 404 for show, edit, update, destroy and tagging" do
    note = personal_notes(:spouse_grieving)

    [
      -> { get household_personal_note_path(household_id: @home, id: note) },
      -> { get edit_household_personal_note_path(household_id: @home, id: note) },
      -> { patch household_personal_note_path(household_id: @home, id: note), params: { personal_note: { base: base(note), title: "Mine now" } } },
      -> { delete household_personal_note_path(household_id: @home, id: note) },
      -> { post household_personal_note_taggings_path(household_id: @home, personal_note_id: note), params: { name: "ministry" }, as: :turbo_stream },
      -> { delete household_personal_note_tagging_path(household_id: @home, personal_note_id: note, id: tags(:head_ministry)), as: :turbo_stream }
    ].each do |request|
      sign_in identities(:head) # a 404 doesn't keep the session
      request.call
      assert_response :not_found
    end

    assert_equal "Comfort for someone grieving", note.reload.title
    assert_empty note.tags
  end

  test "another person's collection id on create or update: 404" do
    spouse_collection = collections(:spouse_ministry)

    sign_in identities(:head)
    assert_no_difference -> { PersonalNote.count } do
      post household_personal_notes_path(household_id: @home), params: { personal_note: { title: "Prayer", collection_id: spouse_collection.id } }
    end
    assert_response :not_found

    sign_in identities(:head)
    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { base: base(@note), collection_id: spouse_collection.id } }
    assert_response :not_found
    assert_equal collections(:head_quick_references), @note.reload.collection
  end

  test "add and remove a tag on a note" do
    sign_in identities(:head)

    post household_personal_note_taggings_path(household_id: @home, personal_note_id: @note), params: { name: "Ministry" }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action=replace][target='tag_editor_personal_note_#{@note.id}'] template a.Label", text: "#ministry"
    assert_equal [ "ministry" ], @note.tags.map(&:name)

    delete household_personal_note_tagging_path(household_id: @home, personal_note_id: @note, id: tags(:head_ministry)), as: :turbo_stream
    assert_response :success
    assert_empty @note.tags.reload
  end

  test "a non-member: 404" do
    sign_in identities(:outsider)

    get household_personal_notes_path(household_id: @home)

    assert_response :not_found
  end

  test "a child keeps their own notes" do
    sign_in identities(:eli)

    post household_personal_notes_path(household_id: @home), params: { personal_note: { title: "Creation" } }
    note = users(:eli).personal_notes.find_by!(title: "Creation")
    assert_redirected_to household_personal_note_path(household_id: @home, id: note)

    get household_personal_note_path(household_id: @home, id: note)
    assert_response :success
  end

  private

  def base(note)
    note.reload.updated_at.utc.iso8601(6)
  end
end
