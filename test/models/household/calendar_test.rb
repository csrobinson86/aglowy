require "test_helper"

# The week of Monday 16 November 2026 in Chicago: a weekly family study on Tuesdays at 7:00 PM, the midweek meeting on
# Thursday at 7:00 PM and the weekend meeting on Sunday at 10:00 AM (docs/design/calendar.md, How a calendar is put together).
class Household::CalendarTest < ActiveSupport::TestCase
  CHICAGO = ActiveSupport::TimeZone["Central Time (US & Canada)"]
  WEEK = Date.new(2026, 11, 16)..Date.new(2026, 11, 22)

  setup do
    travel_to Time.utc(2026, 11, 16, 12)
    @household = households(:parents)
    @household.update!(time_zone: CHICAGO.name)
    @household.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @study = @household.schedule_family_study(topic: "Proverbs 3", frequency: "weekly", starts_on: Date.new(2026, 11, 17), time_of_day: "19:00")
  end

  test "meetings and sessions in the range, in order" do
    items = calendar(WEEK).items

    assert_equal [ [ "study", "Family study", "Proverbs 3", CHICAGO.local(2026, 11, 17, 19) ],
                   [ "meeting", "Midweek meeting", nil, CHICAGO.local(2026, 11, 19, 19) ],
                   [ "meeting", "Weekend meeting", nil, CHICAGO.local(2026, 11, 22, 10) ] ],
                 items.map { [ it.kind, it.title, it.subtitle, it.starts_at ] }
    assert_equal @study.first_session, items.first.source
    assert_equal CHICAGO.local(2026, 11, 17, 20), items.first.ends_at
  end

  test "a cancelled session is left out" do
    @study.first_session.cancel

    assert_equal [ "Midweek meeting", "Weekend meeting" ], calendar(WEEK).items.map(&:title)
  end

  test "a weekly study shows in a week past the stored-session horizon, as \"Topic not chosen yet\", with nothing stored" do
    assert_equal Date.new(2027, 8, 31), FamilyStudy.horizon
    past_horizon = Date.new(2027, 9, 6)..Date.new(2027, 9, 12)

    items = assert_no_difference -> { FamilyStudy::Session.count } do
      calendar(past_horizon).items
    end

    study = items.find { it.kind == "study" }
    assert_equal [ "Family study", "Topic not chosen yet", CHICAGO.local(2027, 9, 7, 19) ], [ study.title, study.subtitle, study.starts_at ]
    assert study.source.new_record?
  end

  test "items_on a day" do
    calendar = calendar(WEEK)

    assert_equal [ "Midweek meeting" ], calendar.items_on(Date.new(2026, 11, 19)).map(&:title)
    assert_empty calendar.items_on(Date.new(2026, 11, 18))
  end

  test "hiding meetings leaves only the studies" do
    assert_equal [ "study" ], calendar(WEEK, hide: %w[ meetings ]).items.map(&:kind)
    assert_equal [ "meeting", "meeting" ], calendar(WEEK, hide: %w[ family_studies ]).items.map(&:kind)
  end

  test "household events: a several-day visit is all day across its days, field service a timed card; each hidden by its group" do
    visit = @household.events.create!(kind: "co_visit", title: "Circuit overseer's visit", starts_on: Date.new(2026, 11, 17), days: 6, created_by: users(:grandparent))
    @household.events.create!(kind: "field_service", title: "Field service", starts_on: Date.new(2026, 11, 21), time_of_day: "09:30",
                              duration_minutes: 90, frequency: "weekly", location: "Kingdom Hall", created_by: users(:grandparent))

    calendar = calendar(WEEK)

    assert_equal [ visit ], calendar.all_day_items.map(&:source)
    assert_equal [ 2, 6 ], calendar.all_day_items.sole.columns_in(WEEK.to_a)
    assert_equal [ "Circuit overseer's visit" ], calendar.items_on(Date.new(2026, 11, 22)).map(&:title) - [ "Weekend meeting" ]
    assert_equal [ [ "field_service", "Field service", "Kingdom Hall", CHICAGO.local(2026, 11, 21, 9, 30) ] ],
                 calendar.timed_items_on(Date.new(2026, 11, 21)).map { [ it.kind, it.title, it.subtitle, it.starts_at ] }

    assert_equal %w[ field_service ], calendar(WEEK, hide: %w[ meetings family_studies assemblies ]).items.map(&:kind).uniq
    assert_equal %w[ co_visit ], calendar(WEEK, hide: %w[ meetings family_studies field_service ]).items.map(&:kind).uniq
    assert_empty calendar(WEEK, hide: %w[ meetings family_studies assemblies field_service ]).items
  end

  test "a visit that began in an earlier week starts in the first column" do
    @household.events.create!(kind: "co_visit", title: "Circuit overseer's visit", starts_on: Date.new(2026, 11, 13), days: 6, created_by: users(:grandparent))

    assert_equal [ 1, 3 ], calendar(WEEK).all_day_items.sole.columns_in(WEEK.to_a)
  end

  test "the month's bars: a visit across two week rows is in each, clipped to its days" do
    @household.events.create!(kind: "co_visit", title: "Circuit overseer's visit", starts_on: Date.new(2026, 11, 13), days: 6, created_by: users(:grandparent))
    month = calendar(Date.new(2026, 11, 2)..Date.new(2026, 11, 29))
    first_week, second_week, third_week = Date.new(2026, 11, 9)..Date.new(2026, 11, 15), WEEK.to_a, Date.new(2026, 11, 23)..Date.new(2026, 11, 29)

    assert_equal [ 5, 3 ], month.all_day_items_in(first_week.to_a).sole.columns_in(first_week.to_a)
    assert_equal [ 1, 3 ], month.all_day_items_in(second_week).sole.columns_in(second_week)
    assert_empty month.all_day_items_in(third_week.to_a)
  end

  test "nothing planned: no meeting times, no studies and no events" do
    assert_not calendar(WEEK).nothing_planned?

    @household.family_studies.destroy_all
    @household.update_columns(midweek_meeting_wday: nil, midweek_meeting_time: nil, weekend_meeting_wday: nil, weekend_meeting_time: nil)
    assert calendar(WEEK).nothing_planned?

    @household.events.create!(kind: "memorial", title: "Memorial", starts_on: Date.new(2027, 3, 22), created_by: users(:grandparent))
    assert_not calendar(WEEK).nothing_planned?
  end

  test "another member's shared time appears as \"<First name>'s time\", with no href and no done state" do
    time = hannahs_time
    time.complete(on: Date.new(2026, 11, 16))
    memberships(:head_in_parents).share_times

    item = calendar(WEEK).items_on(Date.new(2026, 11, 16)).sole

    assert_equal [ "shared", "Daily Bible reading", "Hannah's time", CHICAGO.local(2026, 11, 16, 6, 30) ], [ item.kind, item.title, item.subtitle, item.starts_at ]
    # The person, never the time: nothing to link to, nothing it opens and no done mark (Trap 3).
    assert_equal users(:head), item.source
    assert_not item.my_time?
    assert_equal({ "my_times" => "My times", "times_#{users(:head).id}" => "Hannah's times" }, calendar(WEEK).time_groups)
    assert_empty calendar(WEEK, hide: [ "times_#{users(:head).id}" ]).items_on(Date.new(2026, 11, 16))
    # Today on Home leaves every member's shared times out at once.
    assert_empty calendar(WEEK, hide: %w[ shared_times ]).items_on(Date.new(2026, 11, 16))
  end

  test "an unshared time doesn't appear" do
    hannahs_time

    assert_empty calendar(WEEK).items.select { it.kind == "shared" }
    assert_equal({ "my_times" => "My times" }, calendar(WEEK).time_groups)
  end

  test "a time shared only with another household doesn't appear" do
    hannahs_time
    memberships(:head_in_home).share_times

    assert_empty calendar(WEEK).items.select { it.kind == "shared" }
  end

  test "the viewer's own shared time shows once, as their own" do
    users(:grandparent).update!(time_zone: CHICAGO.name)
    users(:grandparent).personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: [ 1 ], time_of_day: "06:30", starts_on: Date.new(2026, 11, 1))
    memberships(:grandparent_in_parents).share_times

    assert_equal [ "my_time" ], calendar(WEEK).items_on(Date.new(2026, 11, 16)).map(&:kind)
  end

  test "the viewer's own part is an item on its day, timed on the midweek day and all day otherwise" do
    thursday = add_part(users(:grandparent), kind: "starting_a_conversation", meeting_on: Date.new(2026, 11, 19), minutes: 3)
    saturday = add_part(users(:grandparent), kind: "talk", meeting_on: Date.new(2026, 11, 21), minutes: 5)
    add_part(users(:grandparent), kind: "following_up", meeting_on: Date.new(2026, 11, 26), minutes: 4)

    calendar = calendar(WEEK)
    timed = calendar.timed_items_on(Date.new(2026, 11, 19)).find { it.kind == "meeting_part" }
    all_day = calendar.all_day_items.sole

    assert_equal [ "Your part: Starting a Conversation", "3 min", CHICAGO.local(2026, 11, 19, 19), CHICAGO.local(2026, 11, 19, 21), false, thursday ],
                 [ timed.title, timed.subtitle, timed.starts_at, timed.ends_at, timed.all_day, timed.source ]
    assert_equal [ "Your part: Talk", "5 min", CHICAGO.local(2026, 11, 21), CHICAGO.local(2026, 11, 22), true, saturday ],
                 [ all_day.title, all_day.subtitle, all_day.starts_at, all_day.ends_at, all_day.all_day, all_day.source ]
    assert_equal [ thursday, saturday ], calendar.items.select(&:meeting_part?).map(&:source)
  end

  test "with no meeting times set, a part on any day is all day" do
    part = add_part(users(:grandparent), kind: "talk", meeting_on: Date.new(2026, 11, 19), minutes: 5)
    @household.update_columns(midweek_meeting_wday: nil, midweek_meeting_time: nil, weekend_meeting_wday: nil, weekend_meeting_time: nil)

    assert_equal [ part ], calendar(WEEK).all_day_items.map(&:source)
  end

  test "a part shared with this household shows for another member, titled with the owner's first name" do
    part = add_part(users(:head), kind: "talk", meeting_on: Date.new(2026, 11, 19), minutes: 5)
    part.share_with(@household)

    item = calendar(WEEK).items.find(&:meeting_part?)

    assert_equal [ "meeting_part", "Hannah: Talk", "5 min", CHICAGO.local(2026, 11, 19, 19), part ], [ item.kind, item.title, item.subtitle, item.starts_at, item.source ]
  end

  test "the viewer's own part shared here shows once, as their own" do
    add_part(users(:grandparent), kind: "talk", meeting_on: Date.new(2026, 11, 19), minutes: 5).share_with(@household)

    assert_equal [ "Your part: Talk" ], calendar(WEEK).items.select(&:meeting_part?).map(&:title)
  end

  test "an unshared part of another member doesn't show; a part shared with another household doesn't show here" do
    add_part(users(:head), kind: "talk", meeting_on: Date.new(2026, 11, 19), minutes: 5)
    add_part(users(:head), kind: "following_up", meeting_on: Date.new(2026, 11, 20), minutes: 4).share_with(households(:home))

    assert_empty calendar(WEEK).items.select(&:meeting_part?)
  end

  test "hiding meetings hides parts" do
    add_part(users(:grandparent), kind: "talk", meeting_on: Date.new(2026, 11, 19), minutes: 5)
    add_part(users(:head), kind: "following_up", meeting_on: Date.new(2026, 11, 20), minutes: 4).share_with(@household)

    assert_equal 2, calendar(WEEK).items.count(&:meeting_part?)
    assert_empty calendar(WEEK, hide: %w[ meetings ]).items.select(&:meeting_part?)
    # The phone feed keeps the meetings and leaves the parts out.
    assert_equal %w[ meeting meeting ], calendar(WEEK, hide: %w[ meeting_parts family_studies ]).items.map(&:kind)
  end

  test "the viewer's own parts and those shared here are one query each" do
    add_part(users(:grandparent), kind: "talk", meeting_on: Date.new(2026, 11, 19), minutes: 5)
    add_part(users(:head), kind: "following_up", meeting_on: Date.new(2026, 11, 20), minutes: 4).share_with(@household)
    others = %w[ family_studies assemblies field_service other_events my_times shared_times ]

    titles = assert_queries_count(2) { calendar(WEEK, hide: others).items.select(&:meeting_part?).map(&:title) }

    assert_equal [ "Your part: Talk", "Hannah: Following Up" ], titles
  end

  private
    def calendar(range, hide: [])
      Household::Calendar.new(@household, viewer: users(:grandparent), range:, hide:)
    end

    # Hannah Head's reading on Mondays at 6:30 AM in Chicago, the household's zone.
    def hannahs_time
      users(:head).update!(time_zone: CHICAGO.name)
      users(:head).personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: [ 1 ], time_of_day: "06:30", starts_on: Date.new(2026, 11, 1))
    end

    def add_part(user, **attributes)
      user.meeting_parts.create!(topic: "Hope for the future", **attributes)
    end
end
