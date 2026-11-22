require "test_helper"

# Study guides are kept for 8 weeks (docs/design/study-guide.md, StudyGuide). Notes made from one are the person's own,
# so they stay.
class StudyGuide::PurgeJobTest < ActiveJob::TestCase
  THIS_WEEK = Date.new(2026, 11, 16)

  test "guides older than 8 weeks go with their parts and sources; newer stay" do
    old = StudyGuide.create!(user: users(:head), week_of: THIS_WEEK - 9.weeks)
    part = old.parts.create!(step: "talk", content: valid_study_guide_content("talk"))
    source = old.sources.create!(position: 1, title: "Life and Ministry Meeting Workbook", url: "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/38")
    kept = StudyGuide.create!(user: users(:head), week_of: THIS_WEEK - 8.weeks)

    # Sunday, the last day of the week, so the 8-week-old one is at its oldest.
    travel_to(Time.utc(2026, 11, 22, 4, 55)) { StudyGuide::PurgeJob.perform_now }

    assert_not StudyGuide.exists?(old.id)
    assert_not StudyGuide::Part.exists?(part.id)
    assert_not StudyGuide::Source.exists?(source.id)
    assert StudyGuide.exists?(kept.id)
    assert StudyGuide.exists?(study_guides(:head_nov_9).id)
  end

  test "it runs every day at 4:55am in production" do
    task = Rails.application.config_for(:recurring, env: "production").fetch(:purge_old_study_guides)

    assert_equal "StudyGuide::PurgeJob", task[:class]
    assert_equal "every day at 4:55am", task[:schedule]
  end
end
