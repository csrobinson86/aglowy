require "test_helper"

# When the Get ready cards are made (docs/design/meeting-prep.md, The weekly AI job; Trap 7). Monday 16 November 2026 at
# 3am; each household's midweek meeting is Tuesday at 7pm and its weekend meeting Sunday at 10am, and each is in UTC
# unless a test moves it. The provider answers through WebMock with the recorded reply: no test calls a provider.
class PrepWeek::PrepareJobTest < ActiveJob::TestCase
  PROVIDER = "https://api.anthropic.com/v1/messages".freeze
  WEEK = Date.new(2026, 11, 16)
  MONDAY = Time.utc(2026, 11, 16, 3)
  STEPS = PrepWeek::Card::STEPS.keys

  setup do
    @home = households(:home)
    [ @home, households(:parents), households(:other) ].each { meet_on_tuesdays(it) }
    @home.enable_meeting_helper(by: users(:head))
    @home.enable_meeting_prep(by: users(:head))
    users(:head).accept_ai_terms(understood: true)
  end

  test "prepares this week's cards for a household with Get ready on" do
    stub_provider

    travel_to(MONDAY) { PrepWeek::PrepareJob.perform_now }

    assert_equal STEPS, week_of(@home).cards.map(&:step)
    assert_equal users(:head), week_of(@home).chat.user
    assert_empty PrepWeek::Preparation.all
  end

  test "tries again for a week missing its Watchtower card" do
    week = PrepWeek.create!(household: @home, week_of: WEEK)
    STEPS.first(4).each { prep_card(week, it) }
    stub_provider

    # Tuesday at 3am, the day after Monday's try.
    travel_to(MONDAY + 1.day) { PrepWeek::PrepareJob.perform_now }

    assert_requested(:post, PROVIDER, times: 1) { |request| request.body.include?("cards for: watchtower_study\\n") }
    assert_equal STEPS, week.reload.cards.map(&:step)
  end

  test "skips a household with Get ready off, one with every card, and one before meeting times are set" do
    households(:parents).enable_meeting_helper(by: users(:grandparent))
    other = households(:other)
    other.enable_meeting_helper(by: users(:outsider))
    other.enable_meeting_prep(by: users(:outsider))
    complete = PrepWeek.create!(household: other, week_of: WEEK)
    STEPS.each { prep_card(complete, it) }
    @home.update_columns(midweek_meeting_wday: nil, midweek_meeting_time: nil, weekend_meeting_wday: nil, weekend_meeting_time: nil)
    [ users(:grandparent), users(:outsider) ].each { it.accept_ai_terms(understood: true) }
    stub_provider

    travel_to(MONDAY) { PrepWeek::PrepareJob.perform_now }

    assert_not_requested :post, PROVIDER
    assert_not PrepWeek.exists?(household: [ @home, households(:parents) ], week_of: WEEK)
  end

  test "after the midweek meeting but before the weekend one, it's prepared for the Watchtower card" do
    stub_provider

    # Wednesday at 3am: Tuesday's meeting is over, Sunday's is ahead.
    travel_to(Time.utc(2026, 11, 18, 3)) { PrepWeek::PrepareJob.perform_now }

    assert_equal %w[ watchtower_study ], week_of(@home).cards.map(&:step)
  end

  test "after both meetings, it's skipped" do
    # A Saturday weekend meeting, so the week's Sunday 3am comes after both.
    @home.change_meeting_times(midweek_wday: 2, midweek_time: "19:00", weekend_wday: 6, weekend_time: "10:00")
    stub_provider

    travel_to(Time.utc(2026, 11, 22, 3)) { PrepWeek::PrepareJob.perform_now }

    assert_not_requested :post, PROVIDER
    assert_nil week_of(@home)
  end

  test "the week follows the household's time zone" do
    # Sunday afternoon in UTC is already 3am on Monday the 16th in Auckland.
    @home.update!(time_zone: "Auckland")
    stub_provider

    travel_to(Time.utc(2026, 11, 15, 14)) { PrepWeek::PrepareJob.perform_now }

    assert_equal [ WEEK ], @home.prep_weeks.where.not(id: prep_weeks(:home_nov_9)).pluck(:week_of)
  end

  test "a household behind UTC gets its first try at 3am on its own Monday, and none at another hour" do
    @home.update!(time_zone: "Eastern Time (US & Canada)")
    stub_provider

    # 3am UTC is 10pm on Sunday in New York: not its hour, and still last week there. 8am UTC is 3am on Monday there.
    travel_to(MONDAY) { PrepWeek::PrepareJob.perform_now }
    travel_to(Time.utc(2026, 11, 16, 9)) { PrepWeek::PrepareJob.perform_now }
    assert_not_requested :post, PROVIDER

    travel_to(Time.utc(2026, 11, 16, 8)) { PrepWeek::PrepareJob.perform_now }
    assert_requested :post, PROVIDER, times: 1
    assert_equal STEPS, week_of(@home).cards.map(&:step)
  end

  test "a failure for one household still prepares the next" do
    parents = households(:parents)
    parents.enable_meeting_helper(by: users(:grandparent))
    parents.enable_meeting_prep(by: users(:grandparent))
    users(:grandparent).accept_ai_terms(understood: true)
    stub_request(:post, PROVIDER).to_return(status: 500).then.to_return(**recorded_reply)

    travel_to(MONDAY) do
      assert_error_reported(RubyLLM::ServerError) { PrepWeek::PrepareJob.perform_now }
    end

    assert_requested :post, PROVIDER, times: 2
    assert_equal 1, PrepWeek.where(week_of: WEEK).count
    assert_empty PrepWeek::Preparation.all
  end

  test "with a household, it prepares only that one's week" do
    parents = households(:parents)
    parents.enable_meeting_helper(by: users(:grandparent))
    parents.enable_meeting_prep(by: users(:grandparent))
    users(:grandparent).accept_ai_terms(understood: true)
    stub_provider

    # Any hour: turning Get ready on and accepting the AI terms enqueue it straight away.
    travel_to(MONDAY + 10.hours) { PrepWeek::PrepareJob.perform_now(@home) }

    assert_requested :post, PROVIDER, times: 1
    assert week_of(@home)
    assert_nil week_of(parents)
  end

  test "with a household whose Get ready is off, it does nothing" do
    @home.disable_meeting_prep
    stub_provider

    travel_to(MONDAY) { PrepWeek::PrepareJob.perform_now(@home) }

    assert_not_requested :post, PROVIDER
  end

  test "it runs every hour at minute 30 in production, so every zone has its 3am" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:prepare_prep_weeks)

    assert_equal "PrepWeek::PrepareJob", task[:class]
    assert_equal "every hour at minute 30", task[:schedule]
  end

  private
    def meet_on_tuesdays(household)
      household.change_meeting_times(midweek_wday: 2, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    end

    def week_of(household)
      household.prep_weeks.find_by(week_of: WEEK)
    end

    def recorded_reply
      { status: 200, body: file_fixture("ai/meeting_prep.json").read, headers: { "Content-Type" => "application/json" } }
    end

    def stub_provider
      stub_request(:post, PROVIDER).to_return(**recorded_reply)
    end
end
