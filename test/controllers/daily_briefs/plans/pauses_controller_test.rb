require "test_helper"

class DailyBriefs::Plans::PausesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    sign_in identities(:head)
  end

  test "create pauses the plan by choice and says so on the plan" do
    post household_daily_brief_plan_pause_path(household_id: @home)

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_nil flash[:notice]
    assert_equal "chosen", @plan.reload.pausing.reason

    follow_redirect!
    assert_select ".Banner", text: /Your daily brief is paused/ do
      assert_select "*", text: /You paused it/
      assert_select "form[action=?] input[name=_method][value=delete]", household_daily_brief_plan_pause_path(household_id: @home)
      assert_select "button[type=submit]", "Start it again"
    end
    assert_select "button", text: "Pause the daily brief", count: 0
  end

  test "creating twice is harmless" do
    post household_daily_brief_plan_pause_path(household_id: @home)

    assert_no_difference -> { DailyBrief::Pause.count } do
      post household_daily_brief_plan_pause_path(household_id: @home)
    end

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert @plan.reload.paused?
  end

  test "destroy starts it again from now, and the plan offers Pause the daily brief" do
    @plan.update!(started_at: 5.days.ago)
    @plan.pause(reason: "unseen")
    freeze_time

    delete household_daily_brief_plan_pause_path(household_id: @home)

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_equal "Your daily brief is on again. Your next brief is ready tomorrow morning.", flash[:notice]
    assert_not @plan.reload.paused?
    assert_equal Time.current, @plan.started_at

    follow_redirect!
    assert_select ".Banner", text: /paused/, count: 0
    assert_select "form[action=?]:not(:has(input[name=_method]))", household_daily_brief_plan_pause_path(household_id: @home) do
      assert_select "button[type=submit]", "Pause the daily brief"
    end
  end

  test "with Turbo, pausing and starting again redraw the Banner and the Pause button in place, with focus on the one now there" do
    post household_daily_brief_plan_pause_path(household_id: @home), as: :turbo_stream

    assert_response :success
    assert @plan.reload.paused?
    assert_select "turbo-stream[action=replace][target=daily_brief_paused] template .Banner", text: /Your daily brief is paused/ do
      assert_select "button[type=submit][autofocus]", "Start it again"
    end
    assert_select "turbo-stream[action=replace][target=daily_brief_pause] template" do
      assert_select "button", count: 0
    end
    assert_select "turbo-stream[action=prepend][targets='main .container-xl'] template", text: ""

    delete household_daily_brief_plan_pause_path(household_id: @home), as: :turbo_stream

    assert_response :success
    assert_not @plan.reload.paused?
    assert_select "turbo-stream[action=replace][target=daily_brief_paused] template .Banner", count: 0
    assert_select "turbo-stream[action=replace][target=daily_brief_pause] template button[type=submit][autofocus]", "Pause the daily brief"
    assert_select "turbo-stream[action=prepend][targets='main .container-xl'] template", text: /Your daily brief is on again\./
  end

  test "Start it again from an older tab, on a plan already running, keeps its start and says nothing about the next brief" do
    started_at = 2.days.ago.round

    @plan.update!(started_at:)
    delete household_daily_brief_plan_pause_path(household_id: @home)

    assert_redirected_to household_daily_brief_plan_path(household_id: @home)
    assert_nil flash[:notice]
    assert_equal started_at, @plan.reload.started_at
  end

  test "a plan paused after seven unseen says why" do
    @plan.pause(reason: "unseen")

    get household_daily_brief_plan_path(household_id: @home)

    assert_select ".Banner", text: /You hadn't looked at seven briefs in a row/
  end

  test "someone with no plan gets a 404" do
    sign_in identities(:spouse)

    post household_daily_brief_plan_pause_path(household_id: @home)

    assert_response :not_found
  end

  test "a child is refused" do
    sign_in identities(:eli)

    post household_daily_brief_plan_pause_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)

    @plan.pause(reason: "chosen")
    delete household_daily_brief_plan_pause_path(household_id: @home)
    assert_redirected_to household_root_path(household_id: @home)
    assert @plan.reload.paused?
  end
end
