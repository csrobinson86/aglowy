require "test_helper"

class SharedMeetingNotesControllerTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.utc(2026, 11, 18, 12) }

  test "a member, adult or child, sees the list" do
    meeting_notes(:head_midweek).share_with(households(:home))

    [ identities(:spouse), child_identity ].each do |identity|
      sign_in identity

      get household_shared_meeting_notes_path(household_id: households(:home))

      assert_response :success
      assert_select "title", "Shared in The Head Family · The Head Family · Aglowy"
      assert_select "h1", "Notes"
      assert_select "ul[aria-label='Show'] a[href='#{household_meeting_notes_path(household_id: households(:home))}']", text: "Mine"
      assert_select "ul[aria-label='Show'] a[aria-current='true']", text: /Shared in The Head Family\s+1/
      assert_select "main .Box-row a[href='#{household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_midweek))}']", text: "Life and Ministry"
      assert_select "main .Box-row", text: /Hannah Head · Week of November 16–22, 2026/
      sign_out :identity
    end
  end

  test "a non-member gets 404" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:outsider)

    get household_shared_meeting_notes_path(household_id: households(:home))

    assert_response :not_found
  end

  test "lists only notes shared in this household by active members, newest first" do
    older = users(:spouse).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9))
    older.share_with(households(:home))
    meeting_notes(:head_midweek).share_with(households(:home))
    meeting_notes(:head_weekend).share_with(households(:parents))
    users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 2)) # never shared
    sign_in identities(:spouse)

    get household_shared_meeting_notes_path(household_id: households(:home))

    assert_select "main .Box-row", count: 2
    assert_select "main .Box-row:nth-child(1)", text: /Life and Ministry.*Hannah Head/m
    assert_select "main .Box-row:nth-child(2)", text: /Weekend meeting.*Sam Spouse · Weekend of November 14–15, 2026/m
    assert_select "ul[aria-label='Show'] .Label", "2"
  end

  test "nothing shared yet shows an empty state" do
    sign_in identities(:spouse)

    get household_shared_meeting_notes_path(household_id: households(:home))

    assert_select "main .blankslate h2", "Nothing shared yet"
    assert_select "ul[aria-label='Show'] .Label", "0"
  end

  test "the meeting notes list links to the shared list with its count" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:spouse)

    get household_meeting_notes_path(household_id: households(:home))

    assert_select "ul[aria-label='Show'] a[aria-current='true']", text: "Mine"
    assert_select "ul[aria-label='Show'] a[href='#{household_shared_meeting_notes_path(household_id: households(:home))}']", text: /Shared in The Head Family\s+1/
  end

  test "the Meeting notes tab is selected, Shared is pressed in the switch, and there's no My tags" do
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:head)

    get household_shared_meeting_notes_path(household_id: households(:home))

    assert_select "main nav[aria-label='Notes, meeting notes and bookmarks'] a[aria-current='page'][href='#{household_meeting_notes_path(household_id: households(:home))}']", text: /Meeting notes/
    assert_select "main .Subhead", text: /Your meeting notes are private to you. Share one with your household when you want to./
    assert_select "main ul[aria-label='Show'] a[aria-current='true'][href='#{household_shared_meeting_notes_path(household_id: households(:home))}']", text: /Shared in The Head Family/
    assert_select "main ul[aria-label='Show'] a[aria-current='false']", text: "Mine"
    assert_select "main nav[aria-label='Meetings']", minimum: 1
    assert_select "main nav[aria-label='My tags']", count: 0
    assert_not_includes response.body, "#ministry"
    assert_select "main h2", text: "This week"
    assert_select "main details summary", text: "Meetings and tags"
  end

  test "?kind= narrows the shared list, counting each meeting's shared notes, and an unknown kind is ignored" do
    weekend = users(:spouse).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9))
    weekend.share_with(households(:home))
    meeting_notes(:head_midweek).share_with(households(:home))
    sign_in identities(:spouse)

    get household_shared_meeting_notes_path(household_id: households(:home), kind: "weekend")

    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row", text: /Weekend meeting.*Sam Spouse/m
    assert_select "main h2", text: "This week", count: 0
    assert_select "main .Layout-sidebar nav[aria-label='Meetings'] a[aria-current='page'][href='#{household_shared_meeting_notes_path(household_id: households(:home), kind: "weekend")}']", text: /Weekend meeting\s+1/
    assert_select "main .Layout-sidebar nav[aria-label='Meetings'] a[href='#{household_shared_meeting_notes_path(household_id: households(:home))}']", text: /All meetings\s+2/
    assert_select "main ul[aria-label='Show'] a[href='#{household_meeting_notes_path(household_id: households(:home), kind: "weekend")}']", text: "Mine"

    get household_shared_meeting_notes_path(household_id: households(:home), kind: "teal")

    assert_select "main .Box-row", count: 2
    assert_select "main h2", text: "This week"
  end

  private
    # Charlie Child has no login in the fixtures (a young child needs none), so give them one here.
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
