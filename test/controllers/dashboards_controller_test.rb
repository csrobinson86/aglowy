require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "a visitor is redirected to sign in" do
    get household_root_path(household_id: households(:home))

    assert_redirected_to new_identity_session_path
  end

  test "a member sees the Home header with the household name, and the member list has moved to Members" do
    with_nothing_to_show
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select "h1", "Home"
    assert_select ".Subhead-description", /\AThe Head Family · /
    assert_select ".blankslate h2", "Welcome to The Head Family"
    assert_select "main", text: /Sam Spouse/, count: 0
    assert_select "header a[href='#{new_household_path}']"
  end

  test "the page title is Home · <household> · Aglowy" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "title", "Home · The Head Family · Aglowy"
  end

  test "the household name in the page title is escaped" do
    households(:home).update!(name: "Tom & Jerry <b>")
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_includes response.body, "<title>Home · Tom &amp; Jerry &lt;b&gt; · Aglowy</title>"
  end

  test "a head and an adult see Add a member" do
    with_nothing_to_show
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity

      get household_root_path(household_id: households(:home))

      assert_select ".blankslate p", "Add the people in your household. Family studies, goals and notes will show up here as you add them."
      assert_select ".blankslate a[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"
    end
  end

  test "a child doesn't see Add a member" do
    with_nothing_to_show
    sign_in child_identity

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select ".blankslate p", "Family studies, goals and notes will show up here."
    assert_select "a", { text: "Add a member", count: 0 }
  end

  test "a head's empty state offers Schedule a study first, then Add a member" do
    with_nothing_to_show
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate a.Button--primary[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    assert_select ".blankslate a:not(.Button--primary)[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"
  end

  test "an adult's empty state offers Schedule a study and Add a member; a child's offers nothing" do
    with_nothing_to_show
    sign_in identities(:spouse)
    get household_root_path(household_id: households(:home))
    assert_select ".blankslate a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    assert_select ".blankslate a[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"

    sign_in child_identity
    get household_root_path(household_id: households(:home))
    assert_select ".blankslate a", count: 0
  end

  test "shows the next session and the next three after it" do
    weekly = family_studies(:weekly)
    later = [ 4, 5 ].map { |weeks| weekly.sessions.create!(recurrence_at: weekly.first_session_at + weeks.weeks, scheduled_at: weekly.first_session_at + weeks.weeks) }
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate", count: 0
    assert_select ".Box", text: /Next family study/ do
      assert_select ".Box-header .Label", "Weekly on #{weekly.starts_on.strftime("%A")}s"
      assert_select "h3", "Topic not chosen yet"
      assert_select "a[href='#{session_path(family_study_sessions(:weekly_next))}']", "Open study"
    end
    assert_select ".Box", text: /Coming up/ do
      assert_select ".Box-row a", count: 3
      assert_select ".Box-row:nth-of-type(1) a[href='#{session_path(family_study_sessions(:one_off_first))}']", text: /Draw Close to Jehovah, chapter 1/
      assert_select ".Box-row:nth-of-type(2) a[href='#{session_path(family_study_sessions(:weekly_later))}']"
      assert_select ".Box-row:nth-of-type(3) a[href='#{session_path(later.first)}']"
      assert_select "a[href='#{household_family_studies_path(household_id: households(:home))}']", "All family studies"
    end
    assert_select "a[href='#{session_path(later.last)}']", count: 0
  end

  test "the next session shows its topic and resources" do
    family_study_sessions(:weekly_next).update!(scheduled_at: family_study_sessions(:weekly_next).scheduled_at + 4.days)
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Next family study/ do
      assert_select "h3", "Draw Close to Jehovah, chapter 1"
      assert_select "a[href='#{family_study_resources(:proverbs).url}'][target='_blank'][rel='noopener noreferrer']", family_study_resources(:proverbs).title
      assert_select "a[href='#{family_study_resources(:draw_close).url}']", family_study_resources(:draw_close).title
    end
  end

  test "skips cancelled sessions" do
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select "a[href='#{session_path(family_study_sessions(:weekly_next))}']", "Open study"
    assert_select "a[href='#{session_path(family_study_sessions(:weekly_cancelled))}']", count: 0
    assert_select "main", text: /Cancelled/, count: 0
  end

  test "the empty state when none" do
    households(:home).family_study_sessions.update_all(canceled_at: Time.current)
    with_no_goals_or_notes
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate h2", "Welcome to The Head Family"
    assert_select ".blankslate a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    assert_select "main", text: /Next family study/, count: 0
  end

  test "with one upcoming session there is no Coming up box" do
    households(:home).family_study_sessions.where.not(id: family_study_sessions(:weekly_next)).update_all(canceled_at: Time.current)
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select "a", "Open study"
    assert_select "main", text: /Coming up/, count: 0
  end

  test "a head and an adult can schedule a study from the header once sessions exist; a child can't" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get household_root_path(household_id: households(:home))
      assert_select ".Subhead a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    end

    sign_in child_identity
    get household_root_path(household_id: households(:home))
    assert_select "a", { text: "Schedule a study", count: 0 }
    assert_select "a", "Open study"
  end

  test "the description shows the household's name and today's date in its time zone" do
    households(:home).update_column(:time_zone, "Auckland")
    sign_in identities(:spouse)

    travel_to Time.utc(2026, 11, 13, 12) do
      assert_equal Date.new(2026, 11, 13), Date.current

      get household_root_path(household_id: households(:home))
    end

    assert_select ".Subhead-description", "The Head Family · Saturday, November 14"
  end

  test "with only an active family goal, Home shows the two columns and no Welcome" do
    with_nothing_to_show
    add_goals(households(:home), 1)
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_two_columns
  end

  test "with only a personal goal, Home shows the two columns and no Welcome" do
    with_nothing_to_show
    add_goals(users(:head), 1, set_by: users(:head))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_two_columns
  end

  test "with only a meeting note, Home shows the two columns and no Welcome" do
    with_nothing_to_show
    users(:head).start_meeting_note(kind: "midweek", week_of: Date.current)
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_two_columns
  end

  test "with nothing at all, the Welcome Blankslate shows" do
    with_nothing_to_show
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate h2", "Welcome to The Head Family"
    assert_select "main .Layout", count: 0
    assert_select ".Subhead a", count: 0
  end

  test "with no session but other content, Next family study says none is scheduled" do
    households(:home).family_studies.destroy_all
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Next family study/ do
      assert_select ".color-fg-muted", "No family study scheduled."
    end
    assert_select ".Subhead a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
  end

  test "family goals: at most 3 active ones are listed, set by whom and since when; completed or archived ones are not" do
    households(:home).update_column(:time_zone, "Auckland")
    goals(:gospels).update_column(:created_at, Time.utc(2026, 8, 31, 20))
    later = add_goals(households(:home), 3)
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Family goals/ do
      assert_select ".Box-row", count: 3
      assert_select ".Box-row a[href='#{goal_path(goals(:gospels))}']", "Read the four Gospels together"
      assert_select ".Box-row .f6.color-fg-muted", "Set by Sam · since September 1"
      assert_select ".Box-row a[href='#{goal_path(later.first)}']"
      assert_select ".Box-row a[href='#{goal_path(later.second)}']"
      assert_select "a[href='#{goal_path(later.third)}']", count: 0
      assert_select "a[href='#{goal_path(goals(:proverbs))}']", count: 0
      assert_select "a[href='#{goal_path(goals(:songs))}']", count: 0
      assert_select ".Box-footer a[href='#{household_goals_path(household_id: households(:home))}']", "All family goals"
    end
  end

  test "with no active family goals, the Family goals box says so" do
    goals(:gospels).destroy
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Family goals/ do
      assert_select ".Box-row.color-fg-muted", "No family goals yet."
      assert_select ".Box-footer a", "All family goals"
    end
  end

  test "another household's family goal is never listed" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "main", text: /Read Acts together/, count: 0
  end

  test "My goals lists only the signed-in person's goals; another member's personal goal is not listed, even if shared" do
    goals(:spouse_bible_reading).share_with(households(:home))
    mine = add_goals(users(:head), 4, set_by: users(:head))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "h2", "Mine · follows you to every household"
    assert_select ".Box", text: /My goals/ do
      assert_select ".Box-row a", count: 3
      mine.first(3).each { assert_select ".Box-row a[href='#{goal_path(it)}']", it.title }
      assert_select ".Box-footer a[href='#{household_my_goals_path(household_id: households(:home))}']", "All my goals"
    end
    assert_select "a[href='#{goal_path(mine.last)}']", count: 0
    assert_select "main", text: /Read the whole Bible in a year/, count: 0
  end

  test "with no goals of their own, My goals says so" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /My goals/ do
      assert_select ".Box-row.color-fg-muted", "No goals yet."
    end
  end

  test "Recent meeting notes lists only the signed-in person's 2 newest notes" do
    older = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    theirs = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 23))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Recent meeting notes/ do
      assert_select ".Box-row", count: 2
      assert_select ".Box-row:nth-of-type(1) a[href='#{household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_weekend))}']", "Weekend meeting"
      assert_select ".Box-row:nth-of-type(1) .color-fg-muted", "Weekend of November 21–22, 2026"
      assert_select ".Box-row:nth-of-type(2) a[href='#{household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_midweek))}']", "Life and Ministry"
      assert_select "a[href*='#{older.id}']", count: 0
      assert_select ".Box-footer a[href='#{household_meeting_notes_path(household_id: households(:home))}']", "All meeting notes"
    end
    assert_select "a[href*='#{theirs.id}']", count: 0
  end

  test "with no meeting notes, Recent meeting notes says so" do
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Recent meeting notes/ do
      assert_select ".Box-row.color-fg-muted", "No meeting notes yet."
    end
  end

  test "Home lists up to 5 pinned notes, newest pin first, with a color dot, above Recent meeting notes" do
    notes = pin_notes(6)
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "main .Layout-sidebar h3", text: /\A(My goals|Pinned notes|Recent meeting notes)\z/ do |headings|
      assert_equal [ "My goals", "Pinned notes", "Recent meeting notes" ], headings.map(&:text)
    end
    assert_select ".Box", text: /Pinned notes/ do
      assert_select ".Box-row", count: 5
      notes.reverse.first(5).each.with_index(1) do |note, position|
        assert_select ".Box-row:nth-of-type(#{position}) a[href='#{household_personal_note_path(household_id: households(:home), id: note)}']", note.title
      end
      assert_select ".Box-row:nth-of-type(1) .note-dot.note-dot--yellow"
      assert_select ".Box-row:nth-of-type(1) .sr-only", "Yellow note"
      assert_select "a[href*='#{notes.first.id}']", count: 0
      assert_select ".Box-footer a[href='#{household_personal_notes_path(household_id: households(:home))}']", "All notes"
    end
  end

  test "a person whose only content is a pinned note sees Home's two columns, not the Welcome state" do
    with_nothing_to_show
    personal_notes(:head_daniel).pin_to_top
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_two_columns
    assert_select "main .Layout-sidebar h3", "Pinned notes"
  end

  test "a person with notes but none pinned: no Pinned notes section" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "main .Layout-sidebar h3", "Recent meeting notes"
    assert_select "main h3", text: "Pinned notes", count: 0
    assert_select "main", text: /Daniel 2 image/, count: 0
  end

  test "another member never sees someone else's pinned notes" do
    personal_notes(:spouse_grieving).pin_to_top
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "main h3", text: "Pinned notes", count: 0
    assert_select "main", text: /Comfort for someone grieving/, count: 0
    assert_select "a[href*='#{personal_notes(:spouse_grieving).id}']", count: 0
  end

  test "Home asks no query per goal, note or session" do
    sign_in identities(:head)
    get household_root_path(household_id: households(:home))
    few = queries_during_get

    add_goals(households(:home), 3, set_by: users(:head))
    add_goals(households(:home), 2, set_by: users(:child))
    add_goals(users(:head), 3, set_by: users(:head))
    weekly = family_studies(:weekly)
    [ 4, 5 ].each { |weeks| weekly.sessions.create!(recurrence_at: weekly.first_session_at + weeks.weeks, scheduled_at: weekly.first_session_at + weeks.weeks) }
    users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    pin_notes(3)

    assert_equal few, queries_during_get
  end

  # Thursday 19 November 2026 at 6:00 PM UTC, an hour before the midweek meeting; the home household is in UTC.
  test "on a meeting day an adult sees the Today's meeting card with Open my notes" do
    set_meeting_times
    sign_in identities(:spouse)

    travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }

    assert_select ".todays-meeting-card" do
      assert_select ".todays-meeting-card__icon svg.octicon-sun"
      assert_select "h2", "Today's meeting"
      assert_select ".text-bold", "Midweek meeting · 7:00 PM"
      assert_select "p", "Take notes as you go. They stay yours in every household."
      assert_todays_meeting_button "Open my notes"
    end
    assert_select ".todays-meeting-card + .Layout"
  end

  test "Today shows today's part, and a part shared here by another member" do
    MeetingPart.delete_all # The fixture parts are dated from the real today, so one could land on this day.
    set_meeting_times
    mine = users(:spouse).meeting_parts.create!(kind: "starting_a_conversation", meeting_on: Date.new(2026, 11, 19), minutes: 3, topic: "Hope")
    theirs = users(:head).meeting_parts.create!(kind: "talk", meeting_on: Date.new(2026, 11, 19), minutes: 5, topic: "Trust")
    theirs.share_with(households(:home))
    users(:head).meeting_parts.create!(kind: "following_up", meeting_on: Date.new(2026, 11, 20), minutes: 4, topic: "Hope").share_with(households(:home))
    sign_in identities(:spouse)

    travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }

    assert_select ".today" do
      assert_select "a.calendar-item--meeting-part[href=?]", household_meeting_part_path(household_id: households(:home), id: mine),
                    /7:00 PM\s+Your part: Starting a Conversation\s+3 min/
      assert_select "a.calendar-item--meeting-part[href=?]", household_meeting_part_path(household_id: households(:home), id: theirs), /Hannah: Talk\s+5 min/
      assert_select ".calendar-item--meeting-part", 2
    end
  end

  test "on a meeting day a child with the helper sees Start" do
    set_meeting_times
    households(:home).enable_meeting_helper(by: users(:head))
    sign_in identities(:eli)

    travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }

    assert_select ".todays-meeting-card" do
      assert_select "p", "Listen for things and draw what you see, one part at a time."
      assert_todays_meeting_button "Start"
    end
    assert_select "main", text: /Take notes as you go/, count: 0
  end

  test "on a meeting day a child with the helper off sees Open my notes" do
    set_meeting_times
    sign_in identities(:eli)

    travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }

    assert_select ".todays-meeting-card" do
      assert_select "p", "Take notes as you go. They stay yours in every household."
      assert_todays_meeting_button "Open my notes"
    end
  end

  test "on a meeting day the card shows above the Welcome empty state too" do
    with_nothing_to_show
    set_meeting_times
    sign_in identities(:head)

    travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }

    assert_select ".todays-meeting-card + .Box .blankslate h2", "Welcome to The Head Family"
  end

  test "before a midweek meeting with the helper on, heads and adults see Check this week's listening game on the card" do
    set_meeting_times
    households(:home).enable_meeting_helper(by: users(:head))

    %i[ head spouse ].each do |identity|
      sign_in identities(identity)
      travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }

      assert_select ".todays-meeting-card a[href=?]", household_listening_game_path(household_id: households(:home)), "Check this week's listening game"
    end
  end

  test "Check this week's listening game isn't on the card for a child, with the helper off, or once the meeting has started" do
    set_meeting_times
    households(:home).enable_meeting_helper(by: users(:head))
    sign_in identities(:eli)
    travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }
    assert_select ".todays-meeting-card"
    assert_select "main", text: /Check this week's listening game/, count: 0

    sign_in identities(:head)
    travel_to(Time.utc(2026, 11, 19, 19, 30)) { get household_root_path(household_id: households(:home)) }
    assert_select ".todays-meeting-card"
    assert_select "main", text: /Check this week's listening game/, count: 0

    households(:home).disable_meeting_helper
    travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }
    assert_select ".todays-meeting-card"
    assert_select "main", text: /Check this week's listening game/, count: 0
  end

  test "on a weekend meeting day there's no Check this week's listening game" do
    set_meeting_times
    households(:home).enable_meeting_helper(by: users(:head))
    sign_in identities(:head)

    travel_to(Time.utc(2026, 11, 22, 8)) { get household_root_path(household_id: households(:home)) }

    assert_select ".todays-meeting-card .text-bold", "Weekend meeting · 10:00 AM"
    assert_select "main", text: /Check this week's listening game/, count: 0
  end

  test "the day before a meeting there's no Today's meeting card" do
    set_meeting_times
    sign_in identities(:spouse)

    travel_to(Time.utc(2026, 11, 18, 18)) { get household_root_path(household_id: households(:home)) }

    assert_response :success
    assert_select ".todays-meeting-card", count: 0
    assert_select "main h2", text: "Today's meeting", count: 0
  end

  test "with no meeting times there's no Today's meeting card" do
    sign_in identities(:spouse)

    travel_to(Time.utc(2026, 11, 19, 18)) { get household_root_path(household_id: households(:home)) }

    assert_response :success
    assert_select ".todays-meeting-card", count: 0
    assert_select "main h2", text: "Today's meeting", count: 0
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    get household_root_path(household_id: households(:home))

    assert_response :not_found
  end

  test "a former (inactive) member gets 404" do
    sign_in identities(:former)

    get household_root_path(household_id: households(:home))

    assert_response :not_found
  end

  test "a household_id that isn't a UUID gets 404" do
    sign_in identities(:head)

    get "/not-a-household"

    assert_response :not_found
  end

  # The person's own daily brief, first on Home (docs/design/daily-brief.md, On Home; Trap 5). Tuesday 17 November 2026.
  test "the card shows first, above Today's meeting, for the owner with today's brief" do
    set_meeting_times
    travel_to Time.utc(2026, 11, 19, 15)
    start_daily_brief(users(:head))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".Subhead + .daily-brief-home-card + .todays-meeting-card"
    assert_select ".daily-brief-home-card" do
      assert_select "h2", "Your daily brief"
      assert_select "a[href=?]", household_daily_brief_path(household_id: households(:home)), "Open today's brief"
    end
  end

  test "with the card, Home is kept out of Turbo's snapshot cache and the browser's; without it, it isn't" do
    travel_to Time.utc(2026, 11, 17, 15)
    start_daily_brief(users(:head))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_equal "no-store", response.headers["Cache-Control"]

    sign_in identities(:spouse)
    get household_root_path(household_id: households(:home))
    assert_select "meta[name=turbo-cache-control]", count: 0
    assert_not_equal "no-store", response.headers["Cache-Control"]
  end

  test "links to Home aren't prefetched on hover, as Home marks the brief seen" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    home = household_root_path(household_id: households(:home))
    assert_select "nav a[href=?][data-turbo-prefetch=false]", home, text: "Home"
    assert_select "a[href=?][data-turbo-prefetch=false]", home, text: "Aglowy"
    assert_select "a[href=?]:not([data-turbo-prefetch=false])", home, count: 0
  end

  test "no card with only yesterday's brief" do
    travel_to Time.utc(2026, 11, 17, 15)
    travel_to(3.days.ago) { DailyBrief::Plan.start(users(:head), starter: "husband_and_father") }
    DailyBrief.for(users(:head), on: Date.new(2026, 11, 16))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select ".daily-brief-home-card", count: 0
  end

  test "no card with a paused plan" do
    travel_to Time.utc(2026, 11, 17, 15)
    start_daily_brief(users(:head))
    users(:head).daily_brief_plan.pause(reason: "chosen")
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".daily-brief-home-card", count: 0
  end

  test "no card with no plan" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select ".daily-brief-home-card", count: 0
  end

  test "no card for a child, even one with a brief" do
    travel_to Time.utc(2026, 11, 17, 15)
    brief = start_daily_brief(users(:child))
    sign_in child_identity

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select ".daily-brief-home-card", count: 0
    assert_nil brief.reload.seen_at
  end

  test "another member's Home doesn't have it and never sets seen_at" do
    travel_to Time.utc(2026, 11, 17, 15)
    brief = start_daily_brief(users(:head))
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select ".daily-brief-home-card", count: 0
    assert_nil brief.reload.seen_at
  end

  test "the owner's Home sets seen_at once" do
    travel_to Time.utc(2026, 11, 17, 15)
    brief = start_daily_brief(users(:head))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))
    first = brief.reload.seen_at
    assert_equal Time.current, first

    travel 1.hour
    get household_root_path(household_id: households(:home))
    assert_equal first, brief.reload.seen_at
  end

  # Today's thought, a brief shared with the household, on the other members' Home on its day only
  # (docs/design/daily-brief.md, For the children, and sharing; Traps 5 and 8). Tuesday 17 November 2026.
  test "another member and a child see a shared brief's card today, and seeing it leaves seen_at nil" do
    travel_to Time.utc(2026, 11, 17, 15)
    brief = share_written_brief(users(:head), households(:home))

    [ identities(:spouse), identities(:eli) ].each do |identity|
      sign_in identity
      get household_root_path(household_id: households(:home))

      assert_select ".shared-thought", count: 1 do
        assert_select "h2", "Today's thought"
        assert_select ".Label", "Shared by Hannah Head"
        assert_select ".shared-thought__thread", "A thread for the family."
      end
    end
    assert_nil brief.reload.seen_at
  end

  test "no shared card the day after" do
    travel_to Time.utc(2026, 11, 17, 15)
    share_written_brief(users(:head), households(:home))
    travel 1.day
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select ".shared-thought", count: 0
  end

  test "no shared card in another household" do
    travel_to Time.utc(2026, 11, 17, 15)
    share_written_brief(users(:head), households(:home))
    sign_in identities(:grandparent)

    get household_root_path(household_id: households(:parents))

    assert_response :success
    assert_select ".shared-thought", count: 0
  end

  test "no shared card after sharing stops" do
    travel_to Time.utc(2026, 11, 17, 15)
    brief = share_written_brief(users(:head), households(:home))
    brief.stop_sharing_with(households(:home))
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".shared-thought", count: 0
  end

  test "no shared card for a brief with no written writing" do
    travel_to Time.utc(2026, 11, 17, 15)
    brief = share_written_brief(users(:head), households(:home))
    brief.writings.update_all(status: "failed")
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".shared-thought", count: 0
  end

  test "with only another member's shared card, Home is kept out of Turbo's snapshot cache and the browser's" do
    travel_to Time.utc(2026, 11, 17, 15)
    share_written_brief(users(:head), households(:home))
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".daily-brief-home-card", count: 0
    assert_select ".shared-thought", count: 1
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "the owner doesn't get a second card for their own shared brief" do
    travel_to Time.utc(2026, 11, 17, 15)
    share_written_brief(users(:head), households(:home))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".daily-brief-home-card", count: 1
    assert_select ".shared-thought", count: 0
  end

  private
    # Today's brief for +user+, written, and shared with +household+.
    def share_written_brief(user, household)
      start_daily_brief(user).tap do |brief|
        daily_brief_writing(brief, status: "written", result: { "thread" => "A thread for the family." })
        brief.share_with(household)
      end
    end

    # Midweek on Thursday at 7:00 PM, weekend on Sunday at 10:00 AM.
    def set_meeting_times
      households(:home).change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    end

    def assert_todays_meeting_button(label)
      assert_select "form[action='#{household_todays_meeting_path(household_id: households(:home))}'][method=post]", count: 1 do
        assert_select "input[type=hidden][name='meeting_note[kind]'][value=midweek]"
        assert_select "input[type=hidden][name='meeting_note[week_of]'][value='2026-11-16']"
        assert_select "button.Button--primary.Button--large", label
      end
    end

    def assert_two_columns
      assert_response :success
      assert_select ".blankslate", count: 0
      assert_select "main", text: /Welcome to/, count: 0
      assert_select "main .Layout-main", text: /Next family study/
      assert_select "main .Layout-sidebar" do
        assert_select "h2", "Family goals"
        assert_select "h2", "Mine · follows you to every household"
        assert_select "h3", "My goals"
        assert_select "h3", "Recent meeting notes"
      end
    end

    def session_path(study_session)
      household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end

    def with_nothing_to_show
      households(:home).family_studies.destroy_all
      with_no_goals_or_notes
    end

    def with_no_goals_or_notes
      Goal.destroy_all
      MeetingNote.destroy_all
    end

    def add_goals(owner, count, set_by: users(:spouse))
      count.times.map { owner.goals.create!(title: "Goal #{it}", target_on: Date.new(2027, 6, 1) + it, set_by:) }
    end

    # The head's new notes, pinned a minute apart, oldest pin first; the last is yellow.
    def pin_notes(count)
      count.times.map do |index|
        note = users(:head).personal_notes.create!(title: "Pinned #{index}", color: index == count - 1 ? "yellow" : "none")
        travel_to(Time.current + index.minutes) { note.pin_to_top }
        note
      end
    end

    def goal_path(goal)
      household_goal_path(household_id: households(:home), id: goal)
    end

    def queries_during_get
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[ SCHEMA TRANSACTION ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get household_root_path(household_id: households(:home)) }
      count
    end

    # A plan from the husband-and-father starter, started two days ago, and today's brief from it.
    def start_daily_brief(user)
      travel_to(2.days.ago) { DailyBrief::Plan.start(user, starter: "husband_and_father") }
      DailyBrief.for(user)
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
