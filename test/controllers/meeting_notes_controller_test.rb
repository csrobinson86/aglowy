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
    assert_select "main h3", text: "No earlier notes"
    assert_select "main a[href='#{household_meeting_notes_path(household_id: households(:home), page: Page::LAST - 1)}']", text: "Newer notes"
  end

  test "no earlier notes shows an empty state" do
    sign_in identities(:head)

    get household_meeting_notes_path(household_id: households(:home))

    assert_select "main h2", text: "My notes"
    assert_select "main h3", text: "No earlier notes"
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
    assert_select "main h3", count: 2
    assert_select "main h3", text: "Talk · [This week's talk title]"
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
    assert_select "a", text: "Edit notes", count: 0
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
    assert_select "main", text: /Spiritual gems can't be added here yet./

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

  test "a weekend note can't be edited yet" do
    sign_in identities(:head)

    get edit_note_path(meeting_notes(:head_weekend))

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
