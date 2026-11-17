require "test_helper"

# The done box on a personal time's card (docs/design/calendar.md, My time's done box). Tuesday 17 November 2026 in the
# home household (UTC); Sam Spouse's daily reading.
class PersonalTimes::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 17, 12)
    @home = households(:home)
    users(:spouse).update!(time_zone: "UTC")
    @time = users(:spouse).personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: [ 0, 1, 2, 3, 4, 5, 6 ],
                                                  time_of_day: "06:30", starts_on: Date.new(2026, 11, 1))
    sign_in identities(:spouse)
  end

  test "mark and unmark today" do
    assert_difference -> { @time.completions.count }, 1 do
      post household_personal_time_completions_path(household_id: @home, personal_time_id: @time), params: { on: "2026-11-17" }, as: :turbo_stream
    end
    assert_response :success
    assert_select "turbo-stream[action=replace][target=?]", "personal_time_#{@time.id}_2026-11-17" do
      assert_select "template .calendar-item--my-time.calendar-item--done"
      assert_select "template form[action=?] input[type=checkbox][checked][autofocus]",
                    household_personal_time_completion_path(household_id: @home, personal_time_id: @time, id: "2026-11-17")
    end

    assert_difference -> { @time.completions.count }, -1 do
      delete household_personal_time_completion_path(household_id: @home, personal_time_id: @time, id: "2026-11-17"), as: :turbo_stream
    end
    assert_response :success
    assert_select "turbo-stream[action=replace] template form[action=?] input[type=checkbox]:not([checked])",
                  household_personal_time_completions_path(household_id: @home, personal_time_id: @time)
  end

  test "a future date is refused" do
    assert_no_difference -> { PersonalTime::Completion.count } do
      post household_personal_time_completions_path(household_id: @home, personal_time_id: @time), params: { on: "2026-11-18" }, as: :turbo_stream
    end

    assert_response :unprocessable_content
  end

  test "a date that isn't one is a bad request" do
    post household_personal_time_completions_path(household_id: @home, personal_time_id: @time), params: { on: "soon" }, as: :turbo_stream

    assert_response :bad_request
  end

  test "without Turbo, marking goes back to the calendar's week" do
    post household_personal_time_completions_path(household_id: @home, personal_time_id: @time), params: { on: "2026-11-17" }

    assert_redirected_to household_calendar_path(household_id: @home, date: "2026-11-17")
  end

  test "another person's time is a 404" do
    sign_in identities(:head)

    post household_personal_time_completions_path(household_id: @home, personal_time_id: @time), params: { on: "2026-11-17" }

    assert_response :not_found
  end
end
