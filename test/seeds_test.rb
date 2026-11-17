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
    assert_equal 2, Invitation.count
    assert_equal 2, user("spouse@example.com").households.count
    # Each person has a color, and no two in a household share one (docs/design/avatars.md, Elsewhere).
    Household.find_each { |household| assert_equal household.users.count, household.users.distinct.count(:avatar_color) }
    assert_equal %w[ green ], User.joins(:identity).where(identity: { email: "rivera@example.com" }).pluck(:avatar_color)
    # One adult has a photo Aglowy made, from a gradient drawn in the seed.
    assert_equal [ "image/webp" ], User.joins(:avatar_attachment).map { it.avatar.content_type }
    assert user("spouse@example.com").avatar.attached?
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
    assert_equal 15, MeetingNote.count

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

    rivera = Household.find_by!(name: "The Rivera Family")
    monday = rivera.today.beginning_of_week(:monday)
    assert_equal 4, rivera.events.count
    assert_equal [ monday + 1, 6 ], rivera.events.co_visit.sole.values_at(:starts_on, :days)
    assert_equal monday + 12, rivera.events.circuit_assembly.sole.starts_on
    assert rivera.events.field_service.sole.weekly?
    assert_equal 1, Household::Calendar.new(rivera, viewer: user("rivera@example.com"), range: monday..monday + 6).all_day_items.size

    maria, lucia = user("rivera@example.com"), user("lucia.rivera")
    assert_equal "Pacific Time (US & Canada)", maria.time_zone
    assert_equal %w[ bible_reading meeting_prep personal_study ], maria.personal_times.pluck(:kind).sort
    reading = maria.personal_times.bible_reading.sole
    assert_equal [ reading.today - 1, reading.today ], reading.completions.order(:on).pluck(:on)
    assert_equal maria, maria.personal_times.personal_study.sole.opens.user
    assert_equal "midweek", maria.personal_times.meeting_prep.sole.meeting_note_for(monday + 2, household: rivera).kind
    assert_equal [ "Read a Bible story" ], lucia.personal_times.map(&:title)
    assert_equal [ lucia ], rivera.members_sharing_times.to_a
    my_times = Household::Calendar.new(rivera, viewer: maria, range: monday..monday + 6).items.select(&:my_time?)
    assert_operator my_times.size, :>=, 9
    assert_equal [ "Lucia's time" ], Household::Calendar.new(rivera, viewer: maria, range: monday..monday + 6).items.select(&:shared?).map(&:subtitle).uniq

    # Maria's inbox: Lucia's helper note, then Sam's two notes and a goal, the two oldest read, and one of each
    # scheduled kind (09_notifications.rb).
    assert_equal 7, maria.notifications.visible.count
    assert_equal 5, maria.unread_notifications_count
    assert_equal [ "Sam shared a meeting note", "Sam shared a goal", "Sam shared a meeting note" ], maria.notifications.where(actor: user("spouse@example.com")).newest_first.map(&:title)
    assert_equal %w[ invitation_unaccepted shared_with_you study_topic_needed weekly_preview ], maria.notifications.distinct.pluck(:kind).sort
    assert maria.notifications.all? { it.household == rivera }
    assert_match "was invited 5 days ago", maria.notifications.find_by!(kind: "invitation_unaccepted").body

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
