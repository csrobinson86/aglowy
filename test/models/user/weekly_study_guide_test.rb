require "test_helper"

# The study guide setting, as a record: it exists while the person's study guide is on (docs/design/study-guide.md,
# Models, User::WeeklyStudyGuide). Hannah is a head in home and an adult in parents, Sam an adult in home, Eli a child.
class User::WeeklyStudyGuideTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @head = users(:head)
    @head.accept_ai_terms(understood: "1")
  end

  test "turning it on makes the record, and study_guide_on? says so" do
    assert_not @head.study_guide_on?

    assert @head.turn_on_study_guide

    assert @head.study_guide_on?
    assert User::WeeklyStudyGuide.exists?(user: @head)
  end

  # Turning it on prepares this week straight away (docs/design/study-guide.md, The Settings section), once committed so
  # the job's worker sees the setting.
  test "turning it on enqueues this week's study guide after commit" do
    User.transaction do
      @head.turn_on_study_guide
      assert_no_enqueued_jobs only: StudyGuide::PrepareJob
    end

    assert_enqueued_with job: StudyGuide::PrepareJob, args: [ @head ]
  end

  test "turning it on while it's on enqueues nothing more" do
    @head.turn_on_study_guide

    assert_no_enqueued_jobs(only: StudyGuide::PrepareJob) { @head.turn_on_study_guide }
  end

  test "turning it on twice makes one" do
    @head.turn_on_study_guide

    assert_no_difference("User::WeeklyStudyGuide.count") { assert @head.turn_on_study_guide }
    assert @head.reload.study_guide_on?
  end

  test "without accepted AI terms turning it on returns false and saves nothing" do
    spouse = users(:spouse)
    assert_not spouse.accepted_ai_terms?

    assert_equal false, spouse.turn_on_study_guide

    assert_not spouse.study_guide_on?
    assert_not User::WeeklyStudyGuide.exists?(user: spouse)
  end

  test "terms accepted at an older version don't count" do
    @head.ai_acceptances.update_all(version: Rails.configuration.x.ai.terms_version - 1)

    assert_equal false, @head.turn_on_study_guide
    assert_not User::WeeklyStudyGuide.exists?(user: @head)
  end

  test "turning it off removes it" do
    @head.turn_on_study_guide

    @head.turn_off_study_guide

    assert_not @head.study_guide_on?
    assert_not User::WeeklyStudyGuide.exists?(user: @head)
  end

  test "turning it off while it's off changes nothing" do
    assert_no_difference("User::WeeklyStudyGuide.count") { @head.turn_off_study_guide }
    assert_not @head.study_guide_on?
  end

  # The setting shows for a head or adult in at least one active household (docs/design/study-guide.md, Who can do what).
  test "a head or an adult may have a study guide; a child, or someone whose only adult seat is inactive, may not" do
    assert @head.may_have_study_guide?
    assert users(:spouse).may_have_study_guide?
    assert_not users(:eli).may_have_study_guide?
    assert_not users(:former).may_have_study_guide?
  end

  test "a child here who is an adult in another active household may have one" do
    eli = users(:eli)
    eli.memberships.create!(household: households(:parents), role: "adult")

    assert eli.may_have_study_guide?
  end

  test "deleting the person deletes their setting" do
    @head.turn_on_study_guide

    assert_difference("User::WeeklyStudyGuide.count", -1) { @head.destroy }
  end

  test "database: the unique index on user_id rejects a second row" do
    @head.turn_on_study_guide

    assert_raises ActiveRecord::RecordNotUnique do
      User::WeeklyStudyGuide.insert!({ user_id: @head.id })
    end
  end

  test "database: a setting without a person raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      User::WeeklyStudyGuide.insert!({ user_id: nil })
    end
  end

  test "database: a person who doesn't exist raises InvalidForeignKey" do
    assert_raises ActiveRecord::InvalidForeignKey do
      User::WeeklyStudyGuide.insert!({ user_id: SecureRandom.uuid_v7 })
    end
  end
end
