require "test_helper"

# A done mark for one day of a personal time (docs/design/calendar.md, PersonalTime::Completion). Tuesday 17 November
# 2026 in Sam Spouse's zone, Chicago; the time falls on Tuesdays and Thursdays.
class PersonalTime::CompletionTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 11, 17, 18)
    users(:spouse).update!(time_zone: "Central Time (US & Canada)")
    @time = users(:spouse).personal_times.create!(kind: "bible_reading", title: "Daily Bible reading", wdays: [ 2, 4 ],
                                                  time_of_day: "06:30", starts_on: Date.new(2026, 11, 1))
  end

  test "the database refuses a second mark for the same day" do
    @time.complete(on: Date.new(2026, 11, 17))

    assert_raises(ActiveRecord::RecordNotUnique) do
      PersonalTime::Completion.insert!({ personal_time_id: @time.id, on: Date.new(2026, 11, 17) })
    end
  end

  test "a future day and a day it doesn't fall on are refused" do
    assert_not @time.completions.new(on: Date.new(2026, 11, 19)).valid?
    assert_not @time.completions.new(on: Date.new(2026, 11, 16)).valid?
    assert_not @time.completions.new(on: Date.new(2026, 10, 27)).valid?
    assert @time.completions.new(on: Date.new(2026, 11, 12)).valid?
  end

  test "today is the day in the person's zone" do
    travel_to Time.utc(2026, 11, 18, 3)

    assert @time.completions.new(on: Date.new(2026, 11, 17)).valid?
  end

  test "complete twice makes one row; uncomplete deletes it" do
    assert_difference -> { @time.completions.count }, 1 do
      2.times { @time.complete(on: Date.new(2026, 11, 17)) }
    end

    assert_difference -> { @time.completions.count }, -1 do
      @time.uncomplete(on: Date.new(2026, 11, 17))
    end
  end

  test "complete on a future day raises" do
    assert_raises(ActiveRecord::RecordInvalid) { @time.complete(on: Date.new(2026, 11, 19)) }
  end
end
