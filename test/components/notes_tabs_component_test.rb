require "test_helper"

# Notes' tabs (docs/design/notes.md, Notes, Meeting notes and Bookmarks).
class NotesTabsComponentTest < ViewComponent::TestCase
  setup { @home = households(:home) }

  test "the three tabs with their counts, labelled, each a link with its icon" do
    users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))

    render_inline(NotesTabsComponent.new(selected: :personal_notes, membership: memberships(:head_in_home)))

    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a", count: 3
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[href='/#{@home.id}/notes']", text: /Notes\s+3/
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[href='/#{@home.id}/notes'] svg.octicon-pencil"
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[href='/#{@home.id}/meeting_notes']", text: /Meeting notes\s+3/
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[href='/#{@home.id}/meeting_notes'] svg.octicon-note"
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[href='/#{@home.id}/bookmarks']", text: /Bookmarks\s+1/
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[href='/#{@home.id}/bookmarks'] svg.octicon-bookmark"
  end

  test "the selected tab has aria-current=page, and only that one" do
    render_inline(NotesTabsComponent.new(selected: :meeting_notes, membership: memberships(:head_in_home)))

    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[aria-current='page']", count: 1
    assert_selector "nav[aria-label='Notes, meeting notes and bookmarks'] a[aria-current='page'][href='/#{@home.id}/meeting_notes']", text: "Meeting notes"
  end

  test "the counters are hidden below md" do
    render_inline(NotesTabsComponent.new(selected: :personal_notes, membership: memberships(:spouse_in_home)))

    assert_selector ".Counter.d-none.d-md-inline-block", count: 3
    assert_selector "a[href='/#{@home.id}/notes'] .Counter", text: "1"
    assert_selector "a[href='/#{@home.id}/meeting_notes'] .Counter", text: "0"
    assert_selector "a[href='/#{@home.id}/bookmarks'] .Counter", text: "1"
  end

  test "the Bookmarks tab selected" do
    render_inline(NotesTabsComponent.new(selected: :bookmarks, membership: memberships(:head_in_home)))

    assert_selector "a[aria-current='page'][href='/#{@home.id}/bookmarks']", text: "Bookmarks"
  end
end
