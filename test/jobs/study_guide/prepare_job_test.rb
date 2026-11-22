require "test_helper"

# When the study guide is made (docs/design/study-guide.md, The weekly job; Trap 6). Monday 16 November 2026 at 3:15am
# UTC. Hannah (head in home, adult in parents) has accepted the AI terms and turned her study guide on; everyone is in
# UTC unless a test moves them. The provider answers through WebMock with the recorded reply: no test calls a provider.
class StudyGuide::PrepareJobTest < ActiveJob::TestCase
  PROVIDER = "https://api.anthropic.com/v1/messages".freeze
  WEEK = Date.new(2026, 11, 16)
  MONDAY = Time.utc(2026, 11, 16, 3, 15)
  STEPS = StudyGuide::Part::STEPS.keys

  setup do
    @head = users(:head)
    turn_on(@head)
  end

  test "prepares a person with it on at 3am their time" do
    stub_provider

    travel_to(MONDAY) { StudyGuide::PrepareJob.perform_now }

    assert_equal STEPS, guide(@head).parts.map(&:step)
    assert_equal @head, guide(@head).chat.user
    assert_empty StudyGuide::Preparation.all
  end

  test "none at another hour" do
    stub_provider

    travel_to(MONDAY - 1.hour) { StudyGuide::PrepareJob.perform_now }
    travel_to(MONDAY + 1.hour) { StudyGuide::PrepareJob.perform_now }

    assert_not_requested :post, PROVIDER
    assert_nil guide(@head)
  end

  test "skips a person with no head or adult membership left, and prepares them again once they're an adult somewhere" do
    @head.memberships.update_all(active: false)
    stub_provider

    travel_to(MONDAY) { StudyGuide::PrepareJob.perform_now }

    assert_not_requested :post, PROVIDER
    assert @head.reload.study_guide_on?, "the setting is kept"

    @head.memberships.find_by!(household: households(:parents)).update_column(:active, true)

    travel_to(MONDAY + 1.day) { StudyGuide::PrepareJob.perform_now }

    assert_requested :post, PROVIDER, times: 1
    assert_equal STEPS, guide(@head).parts.map(&:step)
  end

  test "a child somewhere and nothing more is skipped too" do
    eli = users(:eli)
    turn_on(eli)
    stub_provider

    travel_to(MONDAY) { StudyGuide::PrepareJob.perform_now }

    assert_requested :post, PROVIDER, times: 1
    assert_nil guide(eli)
  end

  test "a person behind UTC gets theirs at 3am on their own Monday" do
    @head.update!(time_zone: "Eastern Time (US & Canada)")
    stub_provider

    # 3:15am UTC is 10:15pm on Sunday in New York: not their hour, and still last week there.
    travel_to(MONDAY) { StudyGuide::PrepareJob.perform_now }
    assert_not_requested :post, PROVIDER

    # 8:15am UTC is 3:15am on Monday there.
    travel_to(MONDAY + 5.hours) { StudyGuide::PrepareJob.perform_now }
    assert_requested :post, PROVIDER, times: 1
    assert_equal [ WEEK ], @head.study_guides.where.not(id: study_guides(:head_nov_9)).pluck(:week_of)
  end

  test "a person whose own zone is unset goes by their oldest active household's" do
    households(:home).update!(time_zone: "Auckland")
    stub_provider

    # Sunday 2:15pm UTC is 3:15am on Monday the 16th in Auckland.
    travel_to(Time.utc(2026, 11, 15, 14, 15)) { StudyGuide::PrepareJob.perform_now }

    assert_equal STEPS, guide(@head).parts.map(&:step)
  end

  test "tries again for a week missing parts, asking only for those" do
    week = StudyGuide.create!(user: @head, week_of: WEEK)
    STEPS.first(7).each { week.parts.create!(step: it, content: valid_study_guide_content(it)) }
    stub_provider

    # Tuesday's 3am hour, the day after Monday's try.
    travel_to(MONDAY + 1.day) { StudyGuide::PrepareJob.perform_now }

    assert_requested(:post, PROVIDER, times: 1) { |request| request.body.include?("weekend_overview, watchtower_study") }
    assert_equal STEPS, week.reload.parts.map(&:step)
  end

  test "skips one with every part, and one with it off" do
    week = StudyGuide.create!(user: @head, week_of: WEEK)
    STEPS.each { week.parts.create!(step: it, content: valid_study_guide_content(it)) }
    spouse = users(:spouse)
    spouse.accept_ai_terms(understood: "1")
    stub_provider

    travel_to(MONDAY) { StudyGuide::PrepareJob.perform_now }

    assert_not_requested :post, PROVIDER
    assert_not spouse.study_guide_on?
    assert_nil guide(spouse)
  end

  test "never after the week ends in the person's time zone" do
    week = StudyGuide.create!(user: @head, week_of: WEEK)
    week.parts.create!(step: "talk", content: valid_study_guide_content("talk"))
    stub_provider

    # The next Monday's 3am hour: the week of the 16th is over, so it's next week that's asked for.
    travel_to(MONDAY + 7.days) { StudyGuide::PrepareJob.perform_now }

    assert_equal %w[ talk ], week.reload.parts.map(&:step)
    assert_requested(:post, PROVIDER, times: 1) { |request| request.body.include?("Monday, November 23, 2026") }
    assert @head.study_guides.exists?(week_of: WEEK + 7)
  end

  test "one failure doesn't stop the rest" do
    grandparent = users(:grandparent)
    turn_on(grandparent)
    stub_request(:post, PROVIDER).to_return(status: 500).then.to_return(**recorded_reply)

    travel_to(MONDAY) do
      assert_error_reported(RubyLLM::ServerError) { StudyGuide::PrepareJob.perform_now }
    end

    assert_requested :post, PROVIDER, times: 2
    assert_equal 1, StudyGuide.where(week_of: WEEK).count
    assert_empty StudyGuide::Preparation.all
  end

  test "skips a person who turns it off while the run is preparing someone else's" do
    grandparent = users(:grandparent)
    turn_on(grandparent)
    # During the first person's request, both turn it off: the second, loaded with the batch, must not be asked for.
    stub_request(:post, PROVIDER).to_return do
      [ @head, grandparent ].each(&:turn_off_study_guide)
      recorded_reply
    end

    travel_to(MONDAY) { StudyGuide::PrepareJob.perform_now }

    assert_requested :post, PROVIDER, times: 1
    assert_equal 1, StudyGuide.where(week_of: WEEK).count
  end

  test "with a person, it prepares only theirs, at any hour" do
    turn_on(users(:grandparent))
    stub_provider

    # Turning the setting on enqueues it straight away.
    travel_to(MONDAY + 10.hours) { StudyGuide::PrepareJob.perform_now(@head) }

    assert_requested :post, PROVIDER, times: 1
    assert guide(@head)
    assert_nil guide(users(:grandparent))
  end

  test "with a person whose study guide is off, it does nothing" do
    @head.turn_off_study_guide
    stub_provider

    travel_to(MONDAY) { StudyGuide::PrepareJob.perform_now(@head) }

    assert_not_requested :post, PROVIDER
  end

  test "it runs every hour at minute 15 in production, so every zone has its 3am" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:prepare_study_guides)

    assert_equal "StudyGuide::PrepareJob", task[:class]
    assert_equal "every hour at minute 15", task[:schedule]
  end

  private
    def turn_on(user)
      user.accept_ai_terms(understood: "1")
      user.turn_on_study_guide
    end

    def guide(user)
      user.study_guides.find_by(week_of: WEEK)
    end

    def recorded_reply
      { status: 200, body: file_fixture("ai/study_guide.json").read, headers: { "Content-Type" => "application/json" } }
    end

    def stub_provider
      stub_request(:post, PROVIDER).to_return(**recorded_reply)
    end
end
