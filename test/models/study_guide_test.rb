require "test_helper"

# A person's study guide for one week (docs/design/study-guide.md, StudyGuide).
class StudyGuideTest < ActiveSupport::TestCase
  setup { @guide = study_guides(:head_nov_9) }

  test "database: one guide per person and week" do
    assert_raises(ActiveRecord::RecordNotUnique) { StudyGuide.insert!({ user_id: users(:head).id, week_of: @guide.week_of, created_at: Time.current, updated_at: Time.current }) }
  end

  test "database: a source's address is https" do
    assert_raises(ActiveRecord::CheckViolation) do
      StudyGuide::Source.insert!({ study_guide_id: @guide.id, position: 1, title: "A page", url: "http://wol.jw.org/", created_at: Time.current, updated_at: Time.current })
    end
  end

  test "database: one claim per person and week" do
    StudyGuide::Preparation.create!(user: users(:head), week_of: @guide.week_of, token: SecureRandom.uuid)

    assert_raises(ActiveRecord::RecordNotUnique) do
      StudyGuide::Preparation.insert!({ user_id: users(:head).id, week_of: @guide.week_of, token: SecureRandom.uuid, created_at: Time.current })
    end
  end

  test "parts_for lists a meeting's parts in step order, its overview first" do
    %w[ living midweek_overview bible_reading watchtower_study ].each { @guide.parts.create!(step: it, content: valid_study_guide_content(it)) }
    @guide = StudyGuide.preloaded.find(@guide.id)

    assert_equal %w[ midweek_overview talk bible_reading living ], @guide.parts_for("midweek").map(&:step)
    assert_equal %w[ weekend_overview watchtower_study ], @guide.parts_for("weekend").map(&:step)
  end

  test "deleting the person deletes their guides, parts and claims" do
    user, part = users(:head), study_guide_parts(:head_nov_9_talk)
    StudyGuide::Preparation.create!(user:, week_of: @guide.week_of, token: SecureRandom.uuid)

    user.destroy!

    assert_not StudyGuide.exists?(@guide.id)
    assert_not StudyGuide::Part.exists?(part.id)
    assert_empty StudyGuide::Preparation.all
  end
end
