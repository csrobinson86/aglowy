require "test_helper"

# db/seeds.rb and db/seeds/*.rb: the sample data every page shows in development (story #240). Seeds aren't app code,
# so SimpleCov doesn't count them; this proves they run, add nothing the second time, and nothing leaves the machine.
class SeedsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  # The seeds run on an empty database, as after db:seed:replant: the fixtures share their logins. TRUNCATE is
  # transactional in PostgreSQL, so the test's rollback brings the fixtures back. The model registry keeps its fixture
  # model, so a study's chat finds it; in development replant empties it and RubyLLM reloads its bundled registry.
  setup do
    connection = ActiveRecord::Base.lease_connection
    connection.truncate_tables(*connection.tables - [ RubyLLM::ActiveRecord::Model.table_name ])
  end

  test "one run seeds every feature" do
    seed

    assert_equal [ "The Demo Family", "The Rivera Family" ], Household.order(:name).pluck(:name)
    assert_equal 5, Identity.count
    assert Identity.find_by(username: "lucia.rivera").email.nil?
    assert_equal 1, Invitation.count
    assert_equal 2, user("spouse@example.com").households.count
    assert Household.find_by!(name: "The Rivera Family").meeting_helper?

    assert_equal 4, FamilyStudy.count
    Household.find_each do |household|
      weekly = household.family_studies.weekly.sole
      assert weekly.sessions.upcoming.many?
      today = household.today
      later = household.family_studies.once.sole.starts_on
      assert later > today
      assert later.month == today.month || today == today.end_of_month
      past = weekly.first_session
      assert past.scheduled_at.past?
      assert past.topic.present?
      assert past.notes.present?
      assert_equal 2, past.resources.count
    end

    head = user("head@example.com")
    demo = head.households.sole
    this_week = demo.today.beginning_of_week(:monday)
    assert_equal 11, head.meeting_notes.count
    this_weeks_note = head.meeting_notes.find_by!(kind: "midweek", week_of: this_week)
    assert this_weeks_note.gems.any?
    assert this_weeks_note.filled_parts.any?
    assert_not head.meeting_notes.exists?(kind: "weekend", week_of: this_week)
    assert_equal 2, MeetingNote.shared_with(demo).count
    child_note = user("lucia.rivera").meeting_notes.sole
    assert child_note.marks.any?
    assert child_note.shared_with?(Household.find_by!(name: "The Rivera Family"))
    assert_equal 13, MeetingNote.count

    assert_equal [ 1, 1, 1 ], [ demo.goals.active.count, demo.goals.completed.count, demo.goals.archived.count ]
    steps = demo.goals.active.sole.steps
    assert steps.any?(&:done?)
    assert steps.reject(&:done?).any?
    assert steps.any? { it.assignments.any? }
    assert steps.any?(&:due_on)
    assert_equal 2, head.goals.active.count
    assert_equal 1, Goal.shared_with(demo).count

    assert_equal 6, head.tags.count
    assert head.tags.any? { [ it.meeting_notes, it.goals, it.personal_studies, it.personal_notes ].all?(&:any?) }
    assert_equal %w[ both both notes studies ], head.collections.order(:used_in).pluck(:used_in)

    assert_equal 3, head.personal_studies.count
    assert_equal 3, head.personal_studies.distinct.count(:collection_id)
    assert head.personal_studies.all? { it.notes.body.attachables.any?(Bible::Reference) }
    assert_equal 4, PersonalStudy::Question.answered.count
    assert_equal 1, PersonalStudy::Question.off_topic.count
    assert user("lucia.rivera").memberships.sole.study_ai_grant?
    assert_equal 1, user("lucia.rivera").personal_studies.count

    assert_equal 8, head.personal_notes.count
    assert_equal PersonalNote.colors.keys.sort, head.personal_notes.distinct.pluck(:color).sort
    assert_equal 2, head.personal_notes.pinned.count
    assert_equal 2, head.bookmarks.pages.count
    assert head.bookmarks.pages.all? { it.source.present? && it.title.present? }
    assert_equal [ "Daniel 6:10", "Revelation 21:4" ], head.bookmarks.scriptures.map { it.reference.to_s }.sort
    assert_equal %w[ PersonalNote PersonalStudy ], head.bookmarks.scriptures.map(&:source_type).sort
    assert_equal 2, head.bookmarks.where.not(collection: nil).count
    assert_equal 2, head.bookmarks.count { it.comment.present? }
    assert_equal %w[ courage hope ], head.tags.carried_by("Bookmark").map(&:name).sort
    assert head.personal_notes.any? { it.scripture_references.any? }

    assert_equal 0, Ai::Use.count
  end

  test "a second run adds nothing" do
    seed
    counts = record_counts

    seed

    assert_equal counts, record_counts
  end

  test "seeding enqueues no job, sends no mail and uses none of anyone's AI questions" do
    assert_no_enqueued_jobs do
      assert_no_emails { seed }
    end

    assert_equal 0, Ai::Use.count
  end

  private
    def seed
      Rails.application.load_seed
    end

    def user(login)
      Identity.find_for_database_authentication(login: login).user
    end

    def record_counts
      connection = ActiveRecord::Base.lease_connection
      connection.tables.sort.index_with do |table|
        connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}")
      end
    end
end
