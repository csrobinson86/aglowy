require "test_helper"

# The brief's page and "Prepare today's brief" (docs/design/daily-brief.md, The brief and its states; The morning job).
# Tuesday 17 November 2026 in Hannah's zone; her plan is ready by 5:00 AM and was started on the 1st.
class DailyBriefsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @user = users(:head)
    @user.update!(time_zone: "Central Time (US & Canada)")
    travel_to central(9)
    sign_in identities(:head)
  end

  test "with no plan, show redirects to Start" do
    get household_daily_brief_path(household_id: @home)

    assert_redirected_to new_household_daily_brief_plan_path(household_id: @home)
  end

  test "paused, show says why and offers Start it again" do
    plan = start_plan
    DailyBrief.for(@user)
    plan.pause(reason: "unseen")

    get household_daily_brief_path(household_id: @home)

    assert_response :success
    assert_select "h2", "Your daily brief is paused"
    assert_select "main", text: /You hadn't looked at seven briefs in a row/
    assert_select "form[action=?] button", household_daily_brief_plan_pause_path(household_id: @home), "Start it again"
    assert_nil @user.daily_briefs.sole.seen_at
  end

  test "paused by choice, show says so" do
    start_plan.pause(reason: "chosen")

    get household_daily_brief_path(household_id: @home)

    assert_select "main", text: /You paused it/
  end

  test "before the first brief, show says it's ready tomorrow morning and offers Prepare today's brief" do
    start_plan

    get household_daily_brief_path(household_id: @home)

    assert_response :success
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Daily brief"
    assert_select "h2", "Your first brief is ready tomorrow morning"
    assert_select "form[action=?] button", household_daily_brief_path(household_id: @home), "Prepare today's brief"
  end

  test "before ready-by, show opens yesterday's brief with its date and says when today's is ready" do
    plan = start_plan
    yesterday = travel_to(central(5) - 1.day) { DailyBrief.for(@user) }
    travel_to central(4)

    get household_daily_brief_path(household_id: @home)

    assert_response :success
    assert_select "h1", /Daily brief/
    assert_select "main", text: /Monday, November 16/
    assert_select "main", text: /Today's brief is ready by #{plan.ready_by}/
    assert_select "button", text: "Prepare today's brief", count: 0
    assert yesterday.reload.seen_at
  end

  test "after ready-by with none made, show opens yesterday's and offers Prepare today's brief" do
    start_plan
    travel_to(central(5) - 1.day) { DailyBrief.for(@user) }

    get household_daily_brief_path(household_id: @home)

    assert_select "main", text: /Monday, November 16/
    assert_select "form[action=?] button", household_daily_brief_path(household_id: @home), "Prepare today's brief"
  end

  test "show opens today's brief: the header, the sections from the plan and Today in Aglowy" do
    start_plan
    brief = DailyBrief.for(@user)

    get household_daily_brief_path(household_id: @home)

    assert_response :success
    assert_select "title", "Daily brief · The Head Family · Aglowy"
    assert_select "h1", /Daily brief/
    assert_select "h1 .Label", "Private"
    assert_select "main", text: /Tuesday, November 17 · Only you see this./
    assert_select "a[href=?]", household_daily_brief_plan_path(household_id: @home), "Your plan"
    assert_select "a[href=?]", brief.daily_text_url, "Open the Daily text on wol.jw.org"
    assert_select "h2", "Matthew – John"
    assert_select "h2", "Patience, Mildness"
    assert_select "h2", "Abraham, Moses"
    assert_select "h2", "From your plan"
    assert_select "a[href=?]", Bible::Reference.parse("1 Timothy 3:8-13").jw_url
    assert_select "h2", "Today in Aglowy"
    assert_select "button", text: "Prepare today's brief", count: 0
  end

  test "Today in Aglowy is the person's day when the household's zone is already on the next" do
    start_plan
    DailyBrief.for(@user, on: Date.new(2026, 11, 17))
    @home.events.destroy_all
    { 17 => "Field service", 18 => "Circuit overseer's visit" }.each do |day, title|
      @home.events.create!(kind: "other", title:, starts_on: Date.new(2026, 11, day), time_of_day: "09:30", duration_minutes: 60, created_by: users(:spouse))
    end
    travel_to central(21)

    get household_daily_brief_path(household_id: @home)

    assert_select ".today .Box-header", text: /Tuesday, November 17/
    assert_select ".today__item", text: /Field service/
    assert_select ".today__item", text: /Circuit overseer/, count: 0
  end

  test "the page is kept out of Turbo's snapshot cache and the browser's, so Back can't show it to the next person to sign in" do
    start_plan
    DailyBrief.for(@user)

    get household_daily_brief_path(household_id: @home)

    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "show leaves out the sections the plan turned off" do
    start_plan.update!(sections: %w[ reading ])
    DailyBrief.for(@user)

    get household_daily_brief_path(household_id: @home)

    assert_select "a", text: "Open the Daily text on wol.jw.org", count: 0
    assert_select "h2", text: "Abraham, Moses", count: 0
    assert_select "h2", "Matthew – John"
  end

  test "show sets seen_at once" do
    start_plan
    brief = DailyBrief.for(@user)

    get household_daily_brief_path(household_id: @home)
    first = brief.reload.seen_at
    assert_equal Time.current, first

    travel 1.hour
    get household_daily_brief_path(household_id: @home)
    assert_equal first, brief.reload.seen_at
  end

  test "create makes today's brief and opens it" do
    start_plan

    assert_difference -> { @user.daily_briefs.count } do
      post household_daily_brief_path(household_id: @home)
    end

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_equal Date.new(2026, 11, 17), @user.daily_briefs.sole.on
  end

  test "create makes today's whatever due? says: before ready-by, and for a plan started today" do
    start_plan(at: central(3))
    travel_to central(3, 30)

    assert_difference(-> { @user.daily_briefs.count }) { post household_daily_brief_path(household_id: @home) }
  end

  test "create for a paused plan makes no brief and shows the paused page" do
    start_plan.pause(reason: "chosen")

    assert_no_difference -> { DailyBrief.count } do
      post household_daily_brief_path(household_id: @home)
    end

    follow_redirect!
    assert_select "h2", "Your daily brief is paused"
  end

  test "create with no plan goes to Start" do
    post household_daily_brief_path(household_id: @home)

    assert_redirected_to new_household_daily_brief_plan_path(household_id: @home)
  end

  test "the evening part after 6:00 PM shows the questions, with the section each looks back on, and From this morning" do
    start_plan
    written_brief
    travel_to central(18)

    get household_daily_brief_path(household_id: @home, part: "evening")

    assert_response :success
    assert_select "nav[aria-label='Morning or evening']" do
      assert_select "a[href=?][aria-current=false]", household_daily_brief_path(household_id: @home), "Morning"
      assert_select "a[href=?][aria-current=true]", household_daily_brief_path(household_id: @home, part: "evening"), "Evening"
    end
    assert_select "h2", "Four questions to end the day"
    assert_select "#daily-brief-evening ol li", 4
    assert_select "#daily-brief-evening ol li", text: /Where did I push for my own timing today\?\s*Patience/
    assert_select "#daily-brief-evening ol li", text: /What did I notice about Peter in my reading\?\s*Bible reading/
    assert_select "main", text: /Aglowy doesn't ask for your answers and saves nothing here\./
    assert_select "a[href=?]", new_household_personal_note_path(household_id: @home, title: "Tuesday, November 17"), "Write a note about today"
    assert_select "h2", "Today's brief"
    assert_select "a[href=?]", household_daily_brief_path(household_id: @home), "Show the whole brief"
    assert_select "dd", text: /Matthew 16:21-23 · Peter wants a faster, kinder ending/
    assert_select "dd", text: "Abraham and Moses"
    assert_select "h2", text: "One thing in each role", count: 0
  end

  test "the evening part before 6:00 PM says when the questions open, and doesn't show them" do
    start_plan
    written_brief
    travel_to central(17, 59)

    get household_daily_brief_path(household_id: @home, part: "evening")

    assert_select "h2", "Four questions to end the day"
    assert_select "main", text: /They open here at 6:00 PM\./
    assert_select "main", text: /Where did I push for my own timing today\?/, count: 0
  end

  test "the morning shows the This evening note, which says when they open, and once open links to them" do
    start_plan
    written_brief

    get household_daily_brief_path(household_id: @home)

    assert_select "nav[aria-label='Morning or evening'] a[aria-current=true]", "Morning"
    assert_select "h2", "One thing in each role"
    assert_select "section[aria-labelledby=daily-brief-evening-note-heading]", text: /This evening.*Four questions to end the day\. They open here at 6:00 PM\./m

    travel_to central(18, 30)
    get household_daily_brief_path(household_id: @home)

    assert_select "section[aria-labelledby=daily-brief-evening-note-heading] a[href=?]", household_daily_brief_path(household_id: @home, part: "evening"), "Open them"
  end

  test "with evening off in the brief's copy of the plan there's no switch and no evening note, and part=evening shows the morning" do
    start_plan.update!(sections: DailyBrief::Plan::SECTIONS - [ "evening" ])
    written_brief
    travel_to central(19)

    get household_daily_brief_path(household_id: @home, part: "evening")

    assert_select "nav[aria-label='Morning or evening']", count: 0
    assert_select "#daily-brief-evening-note-heading", count: 0
    assert_select "h2", text: /questions to end the day/, count: 0
    assert_select "h2", "One thing in each role"
  end

  test "with no written writing there's no switch and no evening note" do
    start_plan
    DailyBrief.for(@user)
    travel_to central(19)

    get household_daily_brief_path(household_id: @home, part: "evening")

    assert_select "nav[aria-label='Morning or evening']", count: 0
    assert_select "#daily-brief-evening-note-heading", count: 0
    assert_select "h2", "From your plan"
  end

  test "three questions are three, and the evening page has no form field for an answer" do
    start_plan
    written_brief { |result| result["evening"].pop }
    travel_to central(20)

    get household_daily_brief_path(household_id: @home, part: "evening")

    assert_select "h2", "Three questions to end the day"
    assert_select "#daily-brief-evening ol li", 3
    assert_select "main input:not([type=hidden]), main textarea, main select, main [contenteditable]", count: 0
  end

  test "a child is refused" do
    sign_in identities(:eli)

    get household_daily_brief_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)

    assert_no_difference(-> { DailyBrief.count }) { post household_daily_brief_path(household_id: @home) }
    assert_redirected_to household_root_path(household_id: @home)
  end

  test "another household's URL is a 404" do
    sign_in identities(:outsider)

    get household_daily_brief_path(household_id: @home)

    assert_response :not_found
  end

  private
    def central(hour, minute = 0)
      ActiveSupport::TimeZone["Central Time (US & Canada)"].local(2026, 11, 17, hour, minute)
    end

    def start_plan(at: central(9) - 16.days)
      travel_to(at) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
    end

    # Today's brief written from the saved reply (test/fixtures/files/ai/daily_brief.json), its fields as the checks keep
    # them, after the block has changed them. Written by AI, so the person has accepted the AI terms.
    def written_brief
      @user.accept_ai_terms(understood: "1")
      brief = DailyBrief.for(@user)
      body = JSON.parse(file_fixture("ai/daily_brief.json").read)
      result = JSON.parse(body["content"].filter_map { it["text"] }.join).except("off_topic")
      yield result if block_given?
      daily_brief_writing(brief, status: "written", result:)
      brief
    end
end
