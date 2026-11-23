require "test_helper"

# A week in the Meeting notes tab's Earlier list (docs/design/notes.md, Earlier, a week at a time; frame
# notes-meeting-notes-weeks.png), seen by Hannah Head in her home household.
class MeetingNoteWeekComponentTest < ViewComponent::TestCase
  WEEK = Date.new(2026, 11, 9)

  setup do
    Current.identity = identities(:head)
    Current.membership = memberships(:head_in_home)
  end

  test "open, with both meetings' notes: Life and Ministry first, each linking to its note" do
    midweek, weekend = start("midweek"), start("weekend")

    render_week(notes: [ midweek, weekend ], open: true)

    assert_selector "details[open]"
    assert_selector "details summary[aria-expanded=true]", text: "Week of November 9–15"
    assert_selector "summary .d-md-none", text: "Nov 9–15"
    assert_selector "summary svg.octicon-chevron-right"
    assert_selector "summary", text: "2 notes"
    assert_equal [ "Life and Ministry", "Weekend meeting" ], page.all("details li a.Link--primary").map(&:text)
    assert_selector "li a[href='/#{households(:home).id}/meeting_notes/#{midweek.id}']", text: "Life and Ministry"
    assert_selector "li a[href='/#{households(:home).id}/meeting_notes/#{weekend.id}']", text: "Weekend meeting"
  end

  test "closed, with one note" do
    render_week(notes: [ start("weekend") ], open: false)

    assert_selector "details:not([open])"
    assert_selector "details summary[aria-expanded=false]", text: "Week of November 9–15"
    assert_selector "summary", text: "1 note"
    assert_no_selector "summary", text: "notes"
  end

  test "a dot for each note in its meeting's color" do
    render_week(notes: [ start("midweek"), start("weekend") ])

    assert_selector "summary svg.octicon-dot-fill", count: 2
    assert_selector "summary svg.octicon-dot-fill.color-fg-danger", count: 1
    assert_selector "summary svg.octicon-dot-fill.color-fg-muted", count: 1
  end

  test "Shared on the week when any of its notes is shared, and on that note's row" do
    midweek = start("midweek")
    midweek.share_with(households(:home))

    render_week(notes: [ midweek, start("weekend") ])

    assert_selector "summary .Label", text: "Shared", count: 1
    assert_selector "li .Label", text: "Shared", count: 1
    assert_selector "li", text: /Life and Ministry.*Shared/m
  end

  test "no Shared when none of the week's notes is shared" do
    render_week(notes: [ start("midweek"), start("weekend") ])

    assert_no_selector ".Label", text: "Shared"
  end

  test "each row shows my tags on it" do
    midweek = start("midweek")
    midweek.tag_with("ministry", by: users(:head))

    render_week(notes: [ midweek ])

    assert_selector "li a.Label[href='/#{households(:home).id}/tags/ministry']", text: "#ministry"
  end

  test "Life and Ministry rows drop the week, Weekend rows keep their day" do
    render_week(notes: [ start("midweek"), start("weekend") ])

    assert_selector "li", text: /Weekend meeting\s*Weekend of November 14–15, 2026/
    assert_no_selector "li", text: "Week of November 9–15"
  end

  test "on the shared list, each row names its author, and the week has no Shared" do
    mine = start("midweek")
    theirs = users(:spouse).start_meeting_note(kind: "midweek", week_of: WEEK)
    [ mine, theirs ].each { it.share_with(households(:home)) }

    render_week(notes: [ mine, theirs ], shared_list: true)

    assert_selector "summary", text: "2 notes"
    assert_selector "li", text: /Life and Ministry\s*Hannah Head/
    assert_selector "li", text: /Life and Ministry\s*Sam Spouse/
    assert_no_selector ".Label", text: "Shared"
  end

  test "a week crossing a month names both months" do
    render_week(week_of: Date.new(2026, 10, 26), notes: [ users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 10, 26)) ])

    assert_selector "summary", text: "Week of October 26 – November 1"
    assert_selector "summary .d-md-none", text: "Oct 26 – Nov 1"
  end

  private
    def start(kind)
      users(:head).start_meeting_note(kind:, week_of: WEEK)
    end

    def render_week(notes:, week_of: WEEK, open: true, shared_list: false)
      render_inline(MeetingNoteWeekComponent.new(week_of:, notes: MeetingNote.where(id: notes).includes(:user, :sharings, :tags).in_week_order, open:, shared_list:))
    end
end
