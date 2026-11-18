require "test_helper"

# The weekly research job and its claim (docs/design/listening-game.md, The weekly research job, When it runs; Traps 2,
# 7 and 10). Monday 16 November 2026 at 2am; each household's midweek meeting is Tuesday at 7pm, and each is in UTC
# unless a test moves it. The provider answers through
# WebMock with the recorded reply: no test calls a provider.
class ListeningGame::PrepareJobTest < ActiveJob::TestCase
  PROVIDER = "https://api.anthropic.com/v1/messages".freeze
  WEEK = Date.new(2026, 11, 16)
  MONDAY = Time.utc(2026, 11, 16, 2)

  setup do
    @home = households(:home)
    [ @home, households(:parents), households(:other) ].each { meet_on_tuesdays(it) }
    @home.enable_meeting_helper(by: users(:head))
    users(:head).accept_ai_terms(understood: true)
  end

  test "prepares this week's game for a household with the helper on" do
    stub_provider

    travel_to(MONDAY) { ListeningGame::PrepareJob.perform_now }

    game = game_this_week(@home)
    assert_predicate game.rounds, :any?
    assert_equal users(:head), game.chat.user
    assert_empty ListeningGame::Preparation.all
  end

  test "skips a household with the helper off and one that has this week's game" do
    parents = households(:parents)
    parents.enable_meeting_helper(by: users(:grandparent))
    ListeningGame.create!(household: parents, week_of: WEEK)
    users(:outsider).accept_ai_terms(understood: true)
    stub_provider

    travel_to(MONDAY) { ListeningGame::PrepareJob.perform_now }

    assert_requested :post, PROVIDER, times: 1
    assert_equal [ parents, @home ], ListeningGame.where(week_of: WEEK).map(&:household).sort_by(&:name)
    assert_empty game_this_week(parents).rounds
  end

  test "skips a week whose midweek meeting has passed, and a household without meeting times" do
    households(:parents).update_columns(midweek_meeting_wday: nil, midweek_meeting_time: nil, weekend_meeting_wday: nil, weekend_meeting_time: nil)
    households(:parents).enable_meeting_helper(by: users(:grandparent))
    stub_provider

    # Wednesday at 2am: Tuesday's meeting is over.
    travel_to(Time.utc(2026, 11, 18, 2)) { ListeningGame::PrepareJob.perform_now }

    assert_not_requested :post, PROVIDER
    assert_not ListeningGame.exists?(week_of: WEEK)
  end

  test "a failure for one household still prepares the next" do
    households(:parents).enable_meeting_helper(by: users(:grandparent))
    stub_request(:post, PROVIDER).to_return(status: 500).then.to_return(**recorded_reply)

    travel_to(MONDAY) do
      assert_error_reported(RubyLLM::ServerError) { ListeningGame::PrepareJob.perform_now }
    end

    assert_requested :post, PROVIDER, times: 2
    assert_equal 1, ListeningGame.where(week_of: WEEK).count
    assert_empty ListeningGame::Preparation.all
  end

  test "running twice makes one game" do
    stub_provider

    travel_to(MONDAY) do
      assert_difference(-> { ListeningGame.count }, 1) { 2.times { ListeningGame::PrepareJob.perform_now } }
    end
    assert_requested :post, PROVIDER, times: 1
  end

  test "two runs at once send one request: the second finds a fresh claim" do
    stub_request(:post, PROVIDER).to_return do
      assert_nil @home.prepare_listening_game(WEEK)
      recorded_reply
    end

    travel_to(MONDAY) { ListeningGame::PrepareJob.perform_now }

    assert_requested :post, PROVIDER, times: 1
    assert game_this_week(@home)
    assert_empty ListeningGame::Preparation.all
  end

  test "a claim older than 15 minutes is taken over" do
    travel_to(MONDAY) do
      stale = claim(created_at: 16.minutes.ago)
      stub_provider

      ListeningGame::PrepareJob.perform_now

      assert game_this_week(@home)
      assert_not ListeningGame::Preparation.exists?(stale.id)
    end
  end

  test "a claim under 15 minutes old stops the run" do
    travel_to(MONDAY) do
      held = claim(created_at: 14.minutes.ago)
      stub_provider

      ListeningGame::PrepareJob.perform_now

      assert_not_requested :post, PROVIDER
      assert_equal held.token, held.reload.token
    end
  end

  test "a run whose claim was taken over saves nothing and leaves the newer claim" do
    newer = SecureRandom.uuid
    stub_request(:post, PROVIDER).to_return do
      # Another run takes the claim over while this one's request is out.
      ListeningGame::Preparation.sole.update!(token: newer, created_at: Time.current)
      recorded_reply
    end

    travel_to(MONDAY) { ListeningGame::PrepareJob.perform_now }

    assert_nil game_this_week(@home)
    assert_equal newer, ListeningGame::Preparation.sole.token
  end

  test "a request that times out leaves no claim, and isn't tried again within the run" do
    stub_request(:post, PROVIDER).to_timeout

    travel_to(MONDAY) do
      assert_error_reported(RubyLLM::ConnectionError) { ListeningGame::PrepareJob.perform_now }
    end

    assert_requested :post, PROVIDER, times: 1
    assert_empty ListeningGame::Preparation.all
    assert_nil game_this_week(@home)
  end

  test ":not_allowed never makes a claim" do
    users(:head).ai_acceptances.delete_all

    travel_to(MONDAY) do
      assert_no_queries_match(/INSERT INTO "listening_game_preparations"/) do
        assert_equal :not_allowed, @home.prepare_listening_game(WEEK)
      end
    end
    assert_empty ListeningGame::Preparation.all
  end

  test ":not_allowed sends nothing" do
    users(:head).ai_acceptances.delete_all
    stub_provider

    travel_to(MONDAY) { ListeningGame::PrepareJob.perform_now }

    assert_not_requested :post, PROVIDER
    assert_nil game_this_week(@home)
  end

  test "an acceptance while another run holds a fresh claim lets that run finish and starts nothing new" do
    stub_request(:post, PROVIDER).to_return do
      perform_enqueued_jobs { users(:spouse).accept_ai_terms(understood: true) }
      recorded_reply
    end

    travel_to(MONDAY) do
      ListeningGame::PrepareJob.perform_now
    end

    assert_performed_jobs 1, only: ListeningGame::PrepareJob
    assert_requested :post, PROVIDER, times: 1
    assert_equal users(:head), game_this_week(@home).chat.user
    assert_empty ListeningGame::Preparation.all
  end

  test "a failed request leaves no claim, so the next run tries again" do
    stub_request(:post, PROVIDER).to_return(status: 500).then.to_return(**recorded_reply)

    travel_to(MONDAY) do
      assert_error_reported(RubyLLM::ServerError) { ListeningGame::PrepareJob.perform_now }
      assert_empty ListeningGame::Preparation.all

      ListeningGame::PrepareJob.perform_now
    end

    assert_requested :post, PROVIDER, times: 2
    assert game_this_week(@home)
  end

  test "a reply with nothing usable leaves no claim" do
    body = JSON.parse(recorded_reply[:body])
    body["content"] = [ { "type" => "text", "text" => { off_topic: true, **ListeningGame::STEPS.index_with { [] } }.to_json } ]
    stub_request(:post, PROVIDER).to_return(**recorded_reply, body: body.to_json)

    travel_to(MONDAY) { ListeningGame::PrepareJob.perform_now }

    assert_nil game_this_week(@home)
    assert_empty ListeningGame::Preparation.all
  end

  test "the week follows the household's time zone" do
    # Sunday afternoon in UTC is already 2am on Monday the 16th in Auckland, whose Tuesday meeting is still ahead.
    @home.update!(time_zone: "Auckland")
    stub_provider

    travel_to(Time.utc(2026, 11, 15, 13)) { ListeningGame::PrepareJob.perform_now }

    assert_equal [ WEEK ], @home.listening_games.where.not(id: listening_games(:home_nov_9)).pluck(:week_of)
  end

  test "a household west of UTC with a Monday meeting is prepared at its own 2am, before the meeting" do
    @home.update!(time_zone: "Eastern Time (US & Canada)")
    @home.change_meeting_times(midweek_wday: 1, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    stub_provider

    # 2am UTC is 9pm on Sunday in New York: not its hour. 7am UTC is 2am on Monday there.
    travel_to(MONDAY) { ListeningGame::PrepareJob.perform_now }
    assert_not_requested :post, PROVIDER

    travel_to(Time.utc(2026, 11, 16, 7)) { ListeningGame::PrepareJob.perform_now }
    assert game_this_week(@home)
  end

  test "at any other hour of the household's day it does nothing" do
    stub_provider

    travel_to(MONDAY + 1.hour) { ListeningGame::PrepareJob.perform_now }

    assert_not_requested :post, PROVIDER
  end

  test "a household that has had its 3 requests today sends no fourth, and yesterday's don't count" do
    travel_to(MONDAY - 3.hours) { listening_game_chat }
    travel_to(MONDAY) { 2.times { listening_game_chat } }
    stub_request(:post, PROVIDER).to_return(status: 500)

    travel_to(MONDAY) do
      assert_error_reported(RubyLLM::ServerError) { ListeningGame::PrepareJob.perform_now }
      assert_no_difference(-> { Chat.count }) { assert_nil @home.prepare_listening_game(WEEK) }
    end

    assert_requested :post, PROVIDER, times: 1
    assert_empty ListeningGame::Preparation.all
  end

  test "with a household, it prepares only that one's week" do
    households(:parents).enable_meeting_helper(by: users(:grandparent))
    stub_provider

    travel_to(MONDAY) { ListeningGame::PrepareJob.perform_now(@home) }

    assert_requested :post, PROVIDER, times: 1
    assert game_this_week(@home)
  end

  test "it runs every hour in production, so every zone has its 2am" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:prepare_listening_games)

    assert_equal "ListeningGame::PrepareJob", task[:class]
    assert_equal "every hour at minute 0", task[:schedule]
  end

  private
    def meet_on_tuesdays(household)
      household.change_meeting_times(midweek_wday: 2, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    end

    def claim(created_at:)
      ListeningGame::Preparation.create!(household: @home, week_of: WEEK, token: SecureRandom.uuid, created_at:)
    end

    def listening_game_chat
      Chat.create!(user: users(:head), household: @home, purpose: "listening_game")
    end

    def recorded_reply
      { status: 200, body: file_fixture("ai/listening_game.json").read, headers: { "Content-Type" => "application/json" } }
    end

    def game_this_week(household)
      household.listening_games.find_by(week_of: WEEK)
    end

    def stub_provider
      stub_request(:post, PROVIDER).to_return(**recorded_reply)
    end
end
