require "test_helper"

class MeetingNotesControllerTest < ActionDispatch::IntegrationTest
  # Wednesday of the week the fixture notes are for (16–22 November 2026).
  setup { travel_to Time.utc(2026, 11, 18, 12) }

  test "lists only my notes" do
    mine = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    later = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 23))
    theirs = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 2))
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))

    assert_response :success
    assert_select "title", "Meeting notes · The Head Family · Aglowy"
    assert_select "h1", "Meeting notes"
    assert_select "main", text: /Private to you, wherever you go. Share a note with your household when you want to./
    assert_select "main a[href='#{note_path(mine)}']", count: 1
    assert_select "main a[href='#{note_path(meeting_notes(:head_midweek))}']", text: "Open notes"
    assert_select "main a[href='#{note_path(meeting_notes(:head_weekend))}']", text: "Open notes"
    assert_select "main a[href='#{note_path(theirs)}']", count: 0
    assert_select "main a[href='#{note_path(later)}']", count: 0
    assert_not_includes response.body, "November 2–8"
  end

  test "my notes are the same in every household I belong to" do
    mine = users(:head).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9))
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:parents))

    assert_select "main a[href='#{note_path(mine, households(:parents))}']", count: 1
    assert_select "main a[href='#{note_path(meeting_notes(:head_midweek), households(:parents))}']", text: "Open notes"
  end

  test "this week's cards summarise each note" do
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))

    assert_select "main .Box", text: /Life and Ministry.*Week of November 16–22, 2026 · 2 gems, 2 parts with notes/m
    assert_select "main .Box", text: /Weekend meeting.*Weekend of November 21–22, 2026 · 1 part with notes/m
    assert_select "main form button", text: "Start notes", count: 0
  end

  test "a week not started yet offers Start notes for each meeting" do
    travel_to Time.utc(2026, 11, 25, 12)
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))

    assert_select "main .Box", text: /Week of November 23–29, 2026 · Not started/
    assert_select "main .Box", text: /Weekend of November 28–29, 2026 · Not started/
    assert_select "main form[action='#{household_meeting_notes_path(household_id: households(:home))}']", count: 2
    assert_select "main form input[type=hidden][name='meeting_note[kind]'][value=midweek]"
    assert_select "main form input[type=hidden][name='meeting_note[week_of]'][value='2026-11-23']", count: 2
    assert_select "main form button", text: "Start notes", count: 2
  end

  test "a started note with nothing in it says so" do
    travel_to Time.utc(2026, 11, 25, 12)
    users(:head).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 23))
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))

    assert_select "main .Box", text: /Weekend of November 28–29, 2026 · Nothing written yet/
  end

  test "this week follows my time zone when I've set one, else the household's" do
    travel_to Time.utc(2026, 11, 15, 20) # Sunday evening in UTC, already Monday in Tokyo
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))
    assert_select "main .Box", text: /Week of November 9–15, 2026/

    households(:home).update!(time_zone: "Tokyo")
    get household_meeting_notes_path(household_id: households(:home))
    assert_select "main .Box", text: /Week of November 16–22, 2026/

    users(:head).update!(time_zone: "Pacific Time (US & Canada)")
    get household_meeting_notes_path(household_id: households(:home))
    assert_select "main .Box", text: /Week of November 9–15, 2026/
  end

  test "earlier notes are newest first, 20 at a time" do
    weeks = (0..10).map { Date.new(2026, 11, 9) - it.weeks }
    weeks.each { |week| %w[ midweek weekend ].each { users(:head).start_meeting_note(kind: it, week_of: week) } }
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))

    assert_select "main .Box-row", count: 20
    assert_select "main .Box-row:first-of-type", text: /Weekend meeting.*Weekend of November 14–15, 2026/m
    assert_select "main .Box-row:nth-of-type(2)", text: /Life and Ministry.*Week of November 9–15, 2026/m
    assert_select "main a[href='#{household_meeting_notes_path(household_id: households(:home), page: 2)}']", text: "Older notes"

    get household_meeting_notes_path(household_id: households(:home), page: 2)

    assert_select "main .Box-row", count: 2
    assert_select "main .Box-row", text: /Week of August 31–September 6, 2026/
    assert_select "main a", text: "Older notes", count: 0
    assert_select "main a[href='#{household_meeting_notes_path(household_id: households(:home), page: 1)}']", text: "Newer notes"
  end

  test "a page number past the end or too large shows no notes, not an error" do
    users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home), page: "9" * 20)

    assert_response :success
    assert_select "main h2", text: "No earlier notes"
    assert_select "main a[href='#{household_meeting_notes_path(household_id: households(:home), page: Page::LAST - 1)}']", text: "Newer notes"
  end

  test "no earlier notes shows an empty state" do
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))

    assert_select "main nav[aria-label='Meeting notes'] a[aria-current='page']", text: "My notes"
    assert_select "main h2", text: "No earlier notes"
  end

  test "starting a note twice redirects to the same one" do
    sign_in identities(:spouse)
    path = household_meeting_notes_path(household_id: households(:home))

    assert_difference -> { users(:spouse).meeting_notes.count }, 1 do
      post path, params: { meeting_note: { kind: "midweek", week_of: "2026-11-16" } }
    end
    note = users(:spouse).meeting_notes.sole
    assert_redirected_to note_path(note)
    assert_equal 6, note.parts.count

    assert_no_difference -> { MeetingNote.count } do
      post path, params: { meeting_note: { kind: "midweek", week_of: "2026-11-16" } }
    end
    assert_redirected_to note_path(note)
  end

  test "starting a note without its week is a bad request" do
    sign_in identities(:head)

    assert_no_difference -> { MeetingNote.count } do
      post household_meeting_notes_path(household_id: households(:home)), params: { meeting_note: { kind: "midweek" } }
    end
    assert_response :bad_request
  end

  test "the note shows its kind, the week, the program link and a Private label" do
    sign_in identities(:head)

    get note_path(meeting_notes(:head_midweek))

    assert_response :success
    assert_select "title", "Life and Ministry · The Head Family · Aglowy"
    assert_select "nav[aria-label='Breadcrumb'] a[href='#{household_meeting_notes_path(household_id: households(:home))}']", text: "Meeting notes"
    assert_select "main h1", /\ALife and Ministry\s+Private\z/
    assert_select ".Subhead h1 .Label", "Private"
    assert_select ".Subhead", text: /Week of November 16–22, 2026/
    assert_select "a[href='https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47'][target=_blank][rel=noopener]", text: "This week's program on wol.jw.org"
    assert_select ".Subhead a[href='#{edit_note_path(meeting_notes(:head_midweek))}']", text: "Edit notes"
  end

  test "the note shows filled parts under their sections, and hides empty ones" do
    sign_in identities(:head)

    get note_path(meeting_notes(:head_midweek))

    assert_select "main h2", count: 2
    assert_select "main h2", text: "Treasures From God's Word"
    assert_select "main h2", text: "Living as Christians"
    assert_select "main h2 svg.octicon-dot-fill.color-fg-danger"
    assert_select "main h3", count: 3
    assert_select "main h3", text: "Talk · [This week's talk title]"
    assert_select "main h3", text: "Spiritual Gems"
    assert_select "main", text: /Jehovah promises to strengthen us/
    assert_select "main h3", text: "Congregation Bible Study"
    assert_not_includes response.body, "Bible Reading"
    assert_not_includes response.body, "Field Ministry"
    assert_not_includes response.body, "Nothing written yet."
  end

  test "a weekend note shows the public talk's speaker" do
    sign_in identities(:head)

    get note_path(meeting_notes(:head_weekend))

    assert_select "main h1", /\AWeekend meeting\s+Private\z/
    assert_select ".Subhead", text: /Weekend of November 21–22, 2026/
    assert_select "main h3", text: "Public Talk · [The public talk's title]"
    assert_select "main", text: /Speaker: Daniel Okafor/
    assert_not_includes response.body, "Watchtower Study"
    assert_select "a[href='#{edit_note_path(meeting_notes(:head_weekend))}']", text: "Edit notes"
  end

  test "a weekend note shows the Watchtower Study once something is written in it" do
    meeting_note_parts(:head_watchtower_study).update!(title: "Stay close to Jehovah", notes: "<p>Pray first</p>")
    sign_in identities(:head)

    get note_path(meeting_notes(:head_weekend))

    assert_equal [ "Public Talk", "Watchtower Study" ], css_select("main h2").map { it.text.squish }
    assert_select "main h3", text: "Watchtower Study · Stay close to Jehovah"
    assert_select "main", text: /Pray first/
  end

  test "an empty note says nothing is written yet" do
    note = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    sign_in identities(:head)

    get note_path(note)

    assert_select "main h2", count: 1
    assert_select "main h2", text: "Nothing written yet."
  end

  test "I can open my note from any household I belong to" do
    sign_in identities(:head)

    get note_path(meeting_notes(:head_midweek), households(:parents))

    assert_response :success
    assert_select "main h1", /\ALife and Ministry\s+Private\z/
  end

  test "another person's note id gives 404, even for a head of the same household" do
    theirs = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    sign_in identities(:head)

    get note_path(theirs)

    assert_response :not_found
  end

  test "a non-member of the household gets 404" do
    mine = users(:outsider).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    sign_in identities(:outsider)

    get household_meeting_notes_path(household_id: households(:home))
    assert_response :not_found

    sign_in identities(:outsider) # a 404 doesn't keep the session
    get note_path(mine)
    assert_response :not_found

    sign_in identities(:outsider)
    assert_no_difference -> { MeetingNote.count } do
      post household_meeting_notes_path(household_id: households(:home)), params: { meeting_note: { kind: "weekend", week_of: "2026-11-16" } }
    end
    assert_response :not_found
  end

  test "the edit page has each part's fields, with a uniquely labelled editor for each part's notes" do
    sign_in identities(:head)

    get edit_note_path(meeting_notes(:head_midweek))

    assert_response :success
    assert_select "title", "Edit Life and Ministry · The Head Family · Aglowy"
    assert_select "main h1", /\ALife and Ministry\s+Private\z/
    assert_select "main form[action='#{note_path(meeting_notes(:head_midweek))}'] input[name=_method][value=patch]"
    assert_select "main h2", text: "Treasures From God's Word"
    assert_select "main h2", text: "Apply Yourself to the Field Ministry"
    assert_select "main h2", text: "Living as Christians"
    assert_select "main input[type=text][value=?]", "[This week's talk title]"
    assert_select "main label", text: "Part title"
    assert_select "main label", text: "Notes for the whole section"
    assert_select "main", text: /Each gem is a scripture and what you found in it/

    editors = css_select("main lexxy-editor").reject { it.ancestors("template").any? }
    assert_equal 5, editors.size
    assert_equal editors.size, editors.map { it["id"] }.uniq.size
    labels = editors.map { css_select("label[for='#{it["id"]}']").sole.text.squish }
    assert_equal [ "Notes for Talk", "Notes for Bible Reading", "Notes for the whole section",
                   "Notes for Living as Christians part 1", "Notes for Congregation Bible Study" ], labels

    assert_select "main template lexxy-editor", count: 1
    assert_select "main button", text: "Add another part"
    assert_select "main button[aria-label='Remove Living as Christians part 1']"
    assert_select "main template button[aria-label='Remove Living as Christians part PART_NUMBER']"
    assert_select "main button[type=submit]", text: "Save notes"
    assert_select "main", text: /Only you can see this note./
  end

  test "the author can update titles and notes" do
    sign_in identities(:head)

    patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { parts_attributes: {
      "0" => { id: meeting_note_parts(:head_talk).id, title: "Jehovah holds on to us", notes: "<p>Isaiah 41:10</p>" },
      "4" => { id: meeting_note_parts(:head_living_part).id, title: "Local needs", notes: "<p>The hall cleaning</p>" }
    } } }

    assert_redirected_to note_path(meeting_notes(:head_midweek))
    assert_equal "Notes saved.", flash[:notice]
    assert_equal "Jehovah holds on to us", meeting_note_parts(:head_talk).reload.title
    assert_equal "Isaiah 41:10", meeting_note_parts(:head_talk).notes.to_plain_text
    assert_equal "Local needs", meeting_note_parts(:head_living_part).reload.title
    assert_equal "The hall cleaning", meeting_note_parts(:head_living_part).notes.to_plain_text
  end

  test "adding a Living as Christians part makes it a living part, whatever key is sent" do
    sign_in identities(:head)

    assert_difference -> { meeting_notes(:head_midweek).parts.count }, 1 do
      patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { parts_attributes: {
        "1731900000000" => { title: "Second part", notes: "<p>More</p>", key: "talk", position: "1" }
      } } }
    end

    assert_redirected_to note_path(meeting_notes(:head_midweek))
    added = meeting_notes(:head_midweek).parts.order(:created_at).last
    assert_equal [ "living_part", 7, "Second part" ], [ added.key, added.position, added.title ]
  end

  test "removing a Living as Christians part works" do
    sign_in identities(:head)

    assert_difference -> { MeetingNote::Part.count }, -1 do
      patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { parts_attributes: {
        "4" => { id: meeting_note_parts(:head_living_part).id, _destroy: "1" }
      } } }
    end

    assert_redirected_to note_path(meeting_notes(:head_midweek))
    assert_not MeetingNote::Part.exists?(meeting_note_parts(:head_living_part).id)
  end

  test "removing the Talk part is refused" do
    sign_in identities(:head)

    assert_no_difference -> { MeetingNote::Part.count } do
      patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { parts_attributes: {
        "0" => { id: meeting_note_parts(:head_talk).id, _destroy: "1" }
      } } }
    end

    assert_response :unprocessable_content
    assert MeetingNote::Part.exists?(meeting_note_parts(:head_talk).id)
  end

  test "a part from another note, mine or someone else's, can't be updated through this one" do
    theirs = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16)).parts.first

    [ meeting_note_parts(:head_public_talk), theirs ].each do |part|
      sign_in identities(:head) # a 404 doesn't keep the session
      patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { parts_attributes: {
        "0" => { id: part.id, title: "Overwritten", _destroy: "1" }
      } } }

      assert_response :not_found
      assert_not_equal "Overwritten", part.reload.title
    end
  end

  test "another person gets 404 on the edit page and on saving" do
    sign_in identities(:spouse)

    get edit_note_path(meeting_notes(:head_midweek))
    assert_response :not_found

    sign_in identities(:spouse)
    patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { parts_attributes: {
      "0" => { id: meeting_note_parts(:head_talk).id, title: "Overwritten" }
    } } }
    assert_response :not_found
    assert_equal "[This week's talk title]", meeting_note_parts(:head_talk).reload.title
  end

  test "part titles and notes are filtered from the logs, other titles aren't" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("meeting_note" => { "parts_attributes" => { "0" => { "id" => "1", "title" => "Mine", "notes" => "Mine" } } }, "title" => "Kept")

    assert_equal({ "id" => "1", "title" => "[FILTERED]", "notes" => "[FILTERED]" }, filtered.dig("meeting_note", "parts_attributes", "0"))
    assert_equal "Kept", filtered["title"]
  end

  test "a public talk's speaker is filtered from the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("meeting_note" => { "parts_attributes" => { "0" => { "id" => "1", "speaker" => "Daniel Okafor" } } })

    assert_equal({ "id" => "1", "speaker" => "[FILTERED]" }, filtered.dig("meeting_note", "parts_attributes", "0"))
  end

  test "part titles sent as an array are filtered from the logs too" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("meeting_note" => { "parts_attributes" => [ { "id" => "1", "title" => "Mine" } ] })

    assert_equal [ { "id" => "1", "title" => "[FILTERED]" } ], filtered.dig("meeting_note", "parts_attributes")
  end

  test "part titles and speakers in a query string are filtered from the logged path, other titles aren't" do
    sign_in identities(:head)
    path = edit_note_path(meeting_notes(:head_weekend))

    get "#{path}?meeting_note[parts_attributes][0][speaker]=Samuel&meeting_note%5Bparts_attributes%5D%5B%5D%5Btitle%5D=Refuge&title=Kept"

    assert_equal "#{path}?meeting_note[parts_attributes][0][speaker]=[FILTERED]&meeting_note%5Bparts_attributes%5D%5B%5D%5Btitle%5D=[FILTERED]&title=Kept",
      request.filtered_path
  end

  test "part titles and speakers are filtered from the logged path when the key's names are percent-encoded" do
    sign_in identities(:head)
    path = edit_note_path(meeting_notes(:head_weekend))

    get "#{path}?meeting_note[parts_attributes][0][%73peaker]=Samuel&meeting_n%6Fte[parts_attributes][1][title]=Refuge&%74itle=Kept"

    assert_equal "#{path}?meeting_note[parts_attributes][0][%73peaker]=[FILTERED]&meeting_n%6Fte[parts_attributes][1][title]=[FILTERED]&%74itle=Kept",
      request.filtered_path
  end

  test "the read view lists the gems with their references in bold, in order" do
    sign_in identities(:head)

    get note_path(meeting_notes(:head_midweek))

    assert_select "main ul li", count: 2
    assert_select "main ul li svg.octicon-ruby", count: 2
    assert_equal [ "Isaiah 41:10", "Philippians 4:6-7" ], css_select("main ul li strong").map(&:text)
    assert_select "main ul li", text: /Jehovah doesn't just watch; he takes hold of my hand./
  end

  test "a note with only gems shows them under Treasures From God's Word" do
    note = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    note.gems.create!(scripture: "Ps 23", insight: "He leads.", position: 1)
    sign_in identities(:head)

    get note_path(note)

    assert_select "main h2", text: "Treasures From God's Word"
    assert_select "main h3", text: "Spiritual Gems"
    assert_select "main ul li strong", text: "Psalm 23"
    assert_not_includes response.body, "Nothing written yet."
  end

  test "the edit page has a row for each gem, a template for a new one, and Add a gem" do
    sign_in identities(:head)

    get edit_note_path(meeting_notes(:head_midweek))

    gems = css_select("main fieldset[data-gems-target=gem]").reject { it.ancestors("template").any? }
    assert_equal 2, gems.size
    assert_select "main input[type=text][value=?]", "Isaiah 41:10"
    assert_select "main textarea", text: "Jehovah doesn't just watch; he takes hold of my hand."
    assert_select "main label", text: "Scripture"
    assert_select "main label", text: "What I found"
    assert_select "main button[aria-label='Remove Isaiah 41:10']"
    assert_select "main button[aria-label='Remove Phil 4:6, 7']"
    assert_select "main template fieldset[data-gems-target=gem] input[name*='[gems_attributes][NEW_GEM][scripture]']"
    assert_select "main template button[aria-label='Remove gem GEM_NUMBER']"
    assert_select "main button", text: "Add a gem"
  end

  test "gems are created through the note, numbered after the others" do
    sign_in identities(:head)

    assert_difference -> { meeting_notes(:head_midweek).gems.count }, 2 do
      patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { gems_attributes: {
        "1731900000000" => { scripture: "Isa 41:13", insight: "Don't be afraid.", position: "1" },
        "1731900000001" => { scripture: "Ps 23", insight: "He leads." }
      } } }
    end

    assert_redirected_to note_path(meeting_notes(:head_midweek))
    added = meeting_notes(:head_midweek).gems.last(2)
    assert_equal [ [ 3, "Isa 41:13", 23, 41, 13, "Don't be afraid." ], [ 4, "Ps 23", 19, 23, nil, "He leads." ] ],
                 added.map { [ it.position, it.scripture, it.book_number, it.chapter, it.verse_start, it.insight ] }
  end

  test "gems are updated and removed through the note" do
    sign_in identities(:head)

    patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { gems_attributes: {
      "0" => { id: meeting_note_gems(:head_strength).id, scripture: "Isaiah 41:10-13", insight: "He holds my hand." },
      "1" => { id: meeting_note_gems(:head_anxiety).id, _destroy: "1" }
    } } }

    assert_redirected_to note_path(meeting_notes(:head_midweek))
    gem = meeting_note_gems(:head_strength).reload
    assert_equal [ "Isaiah 41:10-13", 10, 13, "He holds my hand." ], [ gem.scripture, gem.verse_start, gem.verse_end, gem.insight ]
    assert_not MeetingNote::Gem.exists?(meeting_note_gems(:head_anxiety).id)
  end

  test "a gem id from another note can't be changed or removed through this one" do
    theirs = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    gem = theirs.gems.create!(scripture: "John 3:16", insight: "Theirs.", position: 1)

    [ { id: gem.id, insight: "Overwritten" }, { id: gem.id, _destroy: "1" } ].each do |attributes|
      sign_in identities(:head) # a 404 doesn't keep the session
      patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { gems_attributes: { "0" => attributes } } }

      assert_response :not_found
      assert_equal "Theirs.", gem.reload.insight
    end
  end

  test "a bad reference shows its error on that field and keeps everything else typed" do
    sign_in identities(:head)

    assert_no_difference -> { MeetingNote::Gem.count } do
      patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: {
        parts_attributes: { "0" => { id: meeting_note_parts(:head_talk).id, title: "Kept title" } },
        gems_attributes: {
          "0" => { id: meeting_note_gems(:head_strength).id, scripture: "Hezekiah 1:1", insight: "Kept insight" },
          "1731900000000" => { scripture: "Ps 23", insight: "Kept new gem" }
        }
      } }
    end

    assert_response :unprocessable_content
    assert_select "main .FormControl-inlineValidation:not([hidden])", count: 1
    assert_select "main .FormControl-inlineValidation:not([hidden])", text: "Use a reference like Isaiah 41:10."
    assert_select "main input[type=text][value=?][aria-invalid=true]", "Hezekiah 1:1"
    assert_select "main input[type=text][value=?]", "Kept title"
    assert_select "main input[type=text][value=?]", "Ps 23"
    assert_select "main textarea", text: "Kept insight"
    assert_select "main textarea", text: "Kept new gem"
    assert_equal "Isaiah 41:10", meeting_note_gems(:head_strength).reload.scripture
    assert_equal "[This week's talk title]", meeting_note_parts(:head_talk).reload.title
  end

  test "a gem removed before a failed save stays removed on the page" do
    sign_in identities(:head)

    patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { gems_attributes: {
      "0" => { id: meeting_note_gems(:head_strength).id, scripture: "Hezekiah 1:1" },
      "1" => { id: meeting_note_gems(:head_anxiety).id, _destroy: "1" }
    } } }

    assert_response :unprocessable_content
    assert_select "main fieldset[hidden][data-gems-target=gem] input[type=hidden][name*='[_destroy]'][value=true]"
    assert MeetingNote::Gem.exists?(meeting_note_gems(:head_anxiety).id)
  end

  test "a Living as Christians part removed before a failed save stays removed on the page" do
    sign_in identities(:head)

    patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: {
      parts_attributes: { "4" => { id: meeting_note_parts(:head_living_part).id, _destroy: "1" } },
      gems_attributes: { "0" => { id: meeting_note_gems(:head_strength).id, scripture: "Hezekiah 1:1" } }
    } }

    assert_response :unprocessable_content
    assert_select "main fieldset[hidden][data-living-parts-target=part] input[type=hidden][name*='[_destroy]'][value=true]"
    assert MeetingNote::Part.exists?(meeting_note_parts(:head_living_part).id)
  end

  test "an insight keeps its line breaks on the read view" do
    meeting_note_gems(:head_strength).update!(insight: "He holds my hand.\nHe holds me up.")
    sign_in identities(:head)

    get note_path(meeting_notes(:head_midweek))

    assert_select "main ul li span", text: /He holds my hand.\s*He holds me up./ do
      assert_select "br", count: 1
    end
  end

  test "an insight keeps its paragraph breaks on the read view" do
    meeting_note_gems(:head_strength).update!(insight: "He holds my hand.\r\n\r\nHe holds me up.")
    sign_in identities(:head)

    get note_path(meeting_notes(:head_midweek))

    assert_select "main ul li span", text: /He holds my hand.\s*He holds me up./ do
      assert_select "br", count: 2
    end
  end

  test "an insight is shown as plain text on the read view" do
    meeting_note_gems(:head_strength).update!(insight: "<b>Bold</b> claim")
    sign_in identities(:head)

    get note_path(meeting_notes(:head_midweek))

    assert_select "main ul li span", text: /<b>Bold<\/b> claim/
    assert_select "main ul li b", count: 0
  end

  test "gem insights are filtered from the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter("meeting_note" => { "gems_attributes" => { "0" => { "scripture" => "Isaiah 41:10", "insight" => "Mine" } } })

    assert_equal({ "scripture" => "Isaiah 41:10", "insight" => "[FILTERED]" }, filtered.dig("meeting_note", "gems_attributes", "0"))
  end

  test "the weekend edit page follows its outline: the public talk, then a light Watchtower Study" do
    sign_in identities(:head)

    get edit_note_path(meeting_notes(:head_weekend))

    assert_response :success
    assert_select "title", "Edit Weekend meeting · The Head Family · Aglowy"
    assert_select "main h1", /\AWeekend meeting\s+Private\z/
    assert_select ".Subhead", text: /Weekend of November 21–22, 2026/
    assert_equal [ "Public Talk", "Watchtower Study" ], css_select("main h2").map { it.text.squish }
    assert_select "main h3", count: 0
    assert_select "main input[type=text][placeholder='The title the speaker announces'][value=?]", "[The public talk's title]"
    assert_select "main input[type=text][placeholder=Optional][value=?]", "Daniel Okafor"
    assert_select "main label", text: "Talk title"
    assert_select "main label", text: "Speaker"
    assert_select "main label", text: "Article title"
    assert_select "main", text: /Follow along and mark your answers in JW Library. Keep anything you want to remember here./

    editors = css_select("main lexxy-editor")
    assert_equal [ "Notes for Public Talk", "A point to remember" ], editors.map { css_select("label[for='#{it["id"]}']").sole.text.squish }
    assert_equal "Type as the speaker goes: main points, scriptures read, anything to apply.", editors.first["placeholder"]
    assert_equal [ true, false ], editors.map { it.classes.include?("meeting-note-editor--tall") }
    assert editors.all? { it.classes.include?("lexxy-content") }, "a class mustn't replace Lexxy's own"

    assert_select "main template", count: 0
    assert_select "main button", text: /Add/, count: 0
    assert_select "main button[type=submit]", text: "Save notes"
    assert_select "main", text: /Only you can see this note./
  end

  test "the author can save a weekend note's talk title, speaker, notes and Watchtower point" do
    sign_in identities(:head)

    patch note_path(meeting_notes(:head_weekend)), params: { meeting_note: { parts_attributes: {
      "0" => { id: meeting_note_parts(:head_public_talk).id, title: "Find Refuge in Jehovah", speaker: "Samuel Mensah", notes: "<p>Psalm 91</p>" },
      "1" => { id: meeting_note_parts(:head_watchtower_study).id, title: "Stay close to Jehovah", notes: "<p>Pray first</p>" }
    } } }

    assert_redirected_to note_path(meeting_notes(:head_weekend))
    public_talk = meeting_note_parts(:head_public_talk).reload
    assert_equal [ "Find Refuge in Jehovah", "Samuel Mensah", "Psalm 91" ], [ public_talk.title, public_talk.speaker, public_talk.notes.to_plain_text ]
    watchtower_study = meeting_note_parts(:head_watchtower_study).reload
    assert_equal [ "Stay close to Jehovah", "Pray first" ], [ watchtower_study.title, watchtower_study.notes.to_plain_text ]
  end

  test "a weekend note can't take gems" do
    sign_in identities(:head)

    assert_no_difference -> { MeetingNote::Gem.count } do
      patch note_path(meeting_notes(:head_weekend)), params: { meeting_note: { gems_attributes: { "0" => { scripture: "Ps 91", insight: "Refuge" } } } }
    end
    assert_response :unprocessable_content
  end

  test "the author can share from the read and edit views, after a dialog naming who will and won't see it" do
    sign_in identities(:head)

    [ note_path(meeting_notes(:head_midweek)), edit_note_path(meeting_notes(:head_midweek)) ].each do |path|
      get path

      assert_select ".Subhead button svg.octicon-people"
      assert_select ".Subhead button", text: "Share with household"
      assert_select "dialog#share-meeting-note h1", "Share with The Head Family?"
      assert_select "dialog#share-meeting-note", text: /Everyone in The Head Family will be able to read this note, including children. Nobody else can change it./
      assert_select "dialog#share-meeting-note", text: /The Grandparent Family won't see it. You can stop sharing at any time, and if you leave The Head Family it stops automatically./
      assert_select "dialog#share-meeting-note form[action='#{household_meeting_note_sharing_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek))}'][method=post] button", "Share note"
      assert_select "dialog#share-meeting-note button", "Cancel"
    end
  end

  test "the share dialog leaves out other households when I have none" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    sign_in identities(:spouse)

    get note_path(note)

    assert_select "dialog#share-meeting-note", text: /including children/
    assert_select "dialog#share-meeting-note", text: /won't see it/, count: 0
    assert_select "dialog#share-meeting-note", text: /You can stop sharing at any time, and if you leave The Head Family it stops automatically./
  end

  test "a note shared here says so, offers Stop sharing and changes the save hint" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:head)

    get note_path(meeting_notes(:head_midweek))
    assert_select ".Subhead h1 .Label", "Shared with The Head Family"
    assert_select "dialog#share-meeting-note", count: 0
    assert_select ".Subhead form[action='#{household_meeting_note_sharing_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek))}'] input[name=_method][value=delete]"
    assert_select ".Subhead form button", "Stop sharing"

    get edit_note_path(meeting_notes(:head_midweek))
    assert_select "main", text: /Members of The Head Family can read this note./
    assert_not_includes response.body, "Only you can see this note."
  end

  test "a note shared in my other household isn't Private here, and the dialog doesn't claim that household won't see it" do
    meeting_notes(:head_midweek).share_with(households(:parents))
    sign_in identities(:head)

    get edit_note_path(meeting_notes(:head_midweek))

    assert_select ".Subhead h1 .Label", "Shared with The Grandparent Family"
    assert_select ".Subhead button", text: "Share with household"
    assert_select "dialog#share-meeting-note", text: /won't see it/, count: 0
    assert_select "main", text: /Members of The Grandparent Family can read this note./

    meeting_notes(:head_midweek).share_with(households(:home))
    get edit_note_path(meeting_notes(:head_midweek))

    assert_select ".Subhead h1 .Label", "Shared with The Grandparent Family and The Head Family"
    assert_select "main", text: /Members of The Grandparent Family and The Head Family can read this note./
  end

  test "My notes shows a Shared label on shared notes" do
    shared = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    users(:head).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9))
    shared.share_with(households(:home))
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))

    assert_select "main .Box-row .Label", count: 1
    assert_select "main .Box-row", text: /Life and Ministry.*Shared/m
  end

  test "a member can read a shared note" do
    meeting_notes(:head_midweek).share_with(households(:home))
    meeting_notes(:head_midweek).share_with(households(:parents))
    sign_in identities(:spouse)

    get note_path(meeting_notes(:head_midweek))

    assert_response :success
    assert_select "main h1", /\ALife and Ministry\s+Shared by Hannah Head\z/
    assert_select ".Subhead h1 .Label", "Shared by Hannah Head"
    assert_select "main", text: /Hannah Head shared this note with The Head Family. You can read it but not change it./
    assert_select "main h3", text: "Talk · [This week's talk title]"
    assert_select "main li", text: /Isaiah 41:10 — Jehovah doesn't just watch/
    assert_select "main", text: /Parts Hannah Head left empty aren't shown./
    assert_select "main h3", text: "Bible Reading", count: 0
    assert_select "main a[href='#{edit_note_path(meeting_notes(:head_midweek))}']", count: 0
    assert_select "main form", count: 0
    assert_select "main", text: /Edit notes|Share with household|Stop sharing|Save notes|The Grandparent Family/, count: 0
  end

  test "a member can't edit a shared note (404)" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:spouse)

    get edit_note_path(meeting_notes(:head_midweek))
    assert_response :not_found

    sign_in identities(:spouse)
    patch note_path(meeting_notes(:head_midweek)), params: { meeting_note: { parts_attributes: [ { id: meeting_note_parts(:head_talk).id, title: "Changed" } ] } }
    assert_response :not_found
    assert_equal "[This week's talk title]", meeting_note_parts(:head_talk).reload.title

    sign_in identities(:spouse)
    delete household_meeting_note_sharing_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek))
    assert_response :not_found
    assert meeting_notes(:head_midweek).shared_with?(households(:home))
  end

  test "a member can't read a shared note once the author leaves" do
    theirs = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    theirs.share_with(households(:home))
    assert memberships(:spouse_in_home).deactivate
    sign_in identities(:head)

    get note_path(theirs)

    assert_response :not_found
  end

  test "a note shared with one household can't be read through another" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:grandparent)

    get note_path(meeting_notes(:head_midweek), households(:parents))

    assert_response :not_found
  end

  private
    def note_path(note, household = households(:home))
      household_meeting_note_path(household_id: household, id: note)
    end

    def edit_note_path(note, household = households(:home))
      edit_household_meeting_note_path(household_id: household, id: note)
    end
end
