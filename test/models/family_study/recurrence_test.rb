require "test_helper"

class FamilyStudy::RecurrenceTest < ActiveSupport::TestCase
  test "daily every 2 days" do
    assert_dates %w[ 2026-11-17 2026-11-19 2026-11-21 2026-11-23 ],
      study(frequency: "daily", interval: 2), from: "2026-11-01", through: "2026-11-24"
  end

  test "weekly every week" do
    assert_dates %w[ 2026-11-17 2026-11-24 2026-12-01 2026-12-08 ],
      study(frequency: "weekly"), from: "2026-11-17", through: "2026-12-08"
  end

  test "weekly every 2 weeks" do
    assert_dates %w[ 2026-11-17 2026-12-01 2026-12-15 2026-12-29 ],
      study(frequency: "weekly", interval: 2), from: "2026-11-17", through: "2026-12-31"
  end

  test "monthly on the third Tuesday" do
    assert_dates %w[ 2026-11-17 2026-12-15 2027-01-19 2027-02-16 ],
      study(frequency: "monthly", week_of_month: 3), from: "2026-11-01", through: "2027-02-28"
  end

  test "monthly on the fifth Tuesday skips months with four" do
    assert_dates %w[ 2026-12-29 2027-03-30 2027-06-29 ],
      study(frequency: "monthly", week_of_month: 5, starts_on: "2026-12-29"), from: "2026-12-01", through: "2027-07-31"
  end

  test "monthly on the last Tuesday, including a month with five" do
    assert_dates %w[ 2026-11-24 2026-12-29 2027-01-26 2027-02-23 2027-03-30 ],
      study(frequency: "monthly", week_of_month: -1, starts_on: "2026-11-24"), from: "2026-11-01", through: "2027-03-31"
  end

  test "monthly every 2 months" do
    assert_dates %w[ 2027-01-19 2027-03-16 ],
      study(frequency: "monthly", interval: 2, week_of_month: 3), from: "2026-12-01", through: "2027-04-30"
  end

  test "stops at ends_on" do
    assert_dates %w[ 2026-11-17 2026-11-24 2026-12-01 ],
      study(frequency: "weekly", ends_on: "2026-12-01"), from: "2026-11-01", through: "2026-12-31"
  end

  test "a range that starts mid-series lines up with starts_on" do
    assert_dates %w[ 2026-12-15 2026-12-29 ],
      study(frequency: "weekly", interval: 2), from: "2026-12-08", through: "2026-12-31"
    assert_dates %w[ 2026-12-11 2026-12-14 ],
      study(frequency: "daily", interval: 3), from: "2026-12-09", through: "2026-12-15"
  end

  test "once inside the range is starts_on" do
    assert_dates %w[ 2026-11-17 ], study, from: "2026-11-17", through: "2026-11-17"
  end

  test "once outside the range is empty" do
    assert_dates [], study, from: "2026-11-18", through: "2026-12-31"
    assert_dates [], study, from: "2026-11-01", through: "2026-11-16"
  end

  test "a range ending before starts_on is empty" do
    assert_dates [], study(frequency: "monthly", week_of_month: 3), from: "2026-10-01", through: "2026-11-16"
  end

  private
    def study(**attributes)
      households(:home).family_studies.new(starts_on: "2026-11-17", time_of_day: "19:00", **attributes)
    end

    def assert_dates(expected, study, from:, through:)
      assert_equal expected.map { Date.parse(it) }, study.recurrence.dates(from: Date.parse(from), through: Date.parse(through))
    end
end
