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

  test "show opens the note for editing, with its scriptures and details beside it" do
    @note.body = "<p>Daniel 2:44, then Daniel 2:31-33, then Daniel 2:44 again</p>"
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
    assert_select "form[action=?]", household_personal_note_path(household_id: @home, id: @note) do
      assert_select "input[name='personal_note[title]'][value=?]", @note.title
      assert_select "select[name='personal_note[collection_id]'] option[selected]", text: "Quick references"
      assert_select "lexxy-editor[name='personal_note[body]']"
      assert_select "button[type=submit]", "Save note"
    end
    assert_select "main", text: /Saved/
    assert_select "#tag_editor_personal_note_#{@note.id} a.Label", "#ministry"
    assert_select "section[aria-labelledby=note-scriptures]" do
      assert_select "a.scripture-link", count: 2
      assert_select "a.scripture-link" do |links|
        assert_equal [ "Daniel 2:44", "Daniel 2:31-33" ], links.map { it.text.strip }
      end
      assert_select "*", text: /Each opens on jw.org, or in JW Library if it's installed./
    end
    assert_select "section[aria-labelledby=note-details]", text: /Created/
    assert_select "dialog#delete-personal-note"
  end

  test "update: title, body, and move to another collection and out of any" do
    sign_in identities(:head)

    patch household_personal_note_path(household_id: @home, id: @note),
          params: { personal_note: { title: "Daniel 2", collection_id: collections(:head_bible_questions).id, body: "<p>Read Daniel 2:44</p>" } }

    assert_redirected_to household_personal_note_path(household_id: @home, id: @note)
    assert_equal "Note saved.", flash[:notice]
    @note.reload
    assert_equal "Daniel 2", @note.title
    assert_equal collections(:head_bible_questions), @note.collection
    assert_equal [ Bible::Reference.find("27:2:44") ], @note.body.body.attachables

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { collection_id: "" } }
    assert_nil @note.reload.collection
  end

  test "update: a title too long, or a body with more than scripture links, shows the page again" do
    sign_in identities(:head)

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { title: "x" * 121 } }
    assert_response :unprocessable_content
    assert_select "main", text: /Title is too long/

    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { body: "<p>A cat</p>#{remote_image_attachment}" } }
    assert_response :unprocessable_content
    assert_nil @note.reload.body.body
  end

  test "destroy" do
    sign_in identities(:head)

    assert_difference -> { PersonalNote.count }, -1 do
      delete household_personal_note_path(household_id: @home, id: @note)
    end
    assert_redirected_to household_personal_notes_path(household_id: @home)
    assert_equal "Note deleted.", flash[:notice]
  end

  test "another person's note: 404 for show, update, destroy and tagging" do
    note = personal_notes(:spouse_grieving)

    [
      -> { get household_personal_note_path(household_id: @home, id: note) },
      -> { patch household_personal_note_path(household_id: @home, id: note), params: { personal_note: { title: "Mine now" } } },
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
    patch household_personal_note_path(household_id: @home, id: @note), params: { personal_note: { collection_id: spouse_collection.id } }
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
end
