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
    # One clock for the seeds and the dates checked below, so midnight can't fall between them.
    freeze_time
    seed

    assert_equal [ "The Demo Family", "The Rivera Family" ], Household.order(:name).pluck(:name)
    assert_equal 6, Identity.count
    assert Identity.find_by(username: "lucia.rivera").email.nil?
    assert_equal 2, Invitation.count
    assert_equal 2, user("spouse@example.com").households.count
    # Each person has a color, and no two in a household share one (docs/design/avatars.md, Elsewhere).
    Household.find_each { |household| assert_equal household.users.count, household.users.distinct.count(:avatar_color) }
    assert_equal %w[ green ], User.joins(:identity).where(identity: { email: "rivera@example.com" }).pluck(:avatar_color)
    # One adult has a photo Aglowy made, from a gradient drawn in the seed.
    assert_equal [ "image/webp" ], User.joins(:avatar_attachment).map { it.avatar.content_type }
    assert user("spouse@example.com").avatar.attached?
    assert Household.find_by!(name: "The Rivera Family").meeting_prep?

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
    assert_equal 28, head.meeting_notes.count
    this_weeks_note = head.meeting_notes.find_by!(kind: "midweek", week_of: this_week)
    assert this_weeks_note.gems.any?
    assert this_weeks_note.filled_parts.any?
    assert_not head.meeting_notes.exists?(kind: "weekend", week_of: this_week)
    assert_equal 2, MeetingNote.shared_with(demo).count
    child_note = user("lucia.rivera").meeting_notes.find_by!(week_of: this_week - 1.week)
    assert child_note.marks.any?
    assert child_note.shared_with?(Household.find_by!(name: "The Rivera Family"))
    assert_equal 7, user("lucia.rivera").meeting_notes.find_by!(kind: "weekend", week_of: this_week).answer.paragraph
    assert_equal 35, MeetingNote.count

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
    daniel = head.personal_studies.find_by!(title: "Daniel's courage")
    assert_equal [ true, false ], daniel.questions.map(&:saved_to_note?)
    assert daniel.note.body.body.attachables.any?(Bible::Reference)
    assert_equal 4, PersonalStudy::Question.answered.count
    assert_equal 1, PersonalStudy::Question.off_topic.count
    assert user("lucia.rivera").memberships.sole.study_ai_grant?
    assert_equal 1, user("lucia.rivera").personal_studies.count

    assert_equal 11, head.personal_notes.count
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

    # Maria's parts, two coming up and two earlier, one shared with the Rivera Family, with scripture links in the
    # preparation, and Lucia's.
    assert_equal [ 2, 2 ], [ maria.meeting_parts.coming_up(maria.today).count, maria.meeting_parts.earlier(maria.today).count ]
    assert_equal [ "Why we use God's name" ], MeetingPart.shared_with(rivera).map(&:topic)
    assert_equal [ "Psalm 37:10, 11" ], maria.meeting_parts.find_by!(kind: "starting_a_conversation").preparation.body.attachables.map(&:to_s)
    assert_equal 1, lucia.meeting_parts.count
    # Her note for the week of her coming conversation, which names it under its header.
    conversation = maria.meeting_parts.find_by!(kind: "starting_a_conversation")
    assert_equal [ conversation ], maria.meeting_notes.find_by!(kind: "midweek", week_of: conversation.week_of).meeting_parts
    outline = conversation.drafts.find_by!(kind: "outline")
    assert_equal [ "outline", "drafted", 3 ], [ outline.kind, outline.status, outline.sources.size ]
    assert_equal [ "Psalm 37:10, 11", "Proverbs 20:5" ], outline.result["points"].pluck("scripture")
    # Sample wording written from that outline, which the panel shows.
    wording = conversation.current_draft_for(maria)
    assert_equal [ "wording", "drafted", outline, outline.result ], [ wording.kind, wording.status, wording.revises, wording.revised_result ]
    assert_equal [ "Psalm 37:10, 11" ], wording.result["lines"].pluck("read").compact_blank

    # Sam's daily brief plan, from the husband-and-father starter (11_daily_briefs.rb).
    plan = user("spouse@example.com").daily_brief_plan
    assert_equal [ "As a husband", "As a father", "Reaching out", "Qualities to focus on", "Growing appreciation for Jehovah" ], plan.focus_areas.map(&:name)
    assert_equal 7, plan.days.count
    assert_equal [ user("spouse@example.com").today ], user("spouse@example.com").daily_briefs.pluck(:on)
    # Today's brief written by AI from the saved reply, with the pages it used.
    writing = user("spouse@example.com").daily_briefs.sole.writing
    assert_equal [ "written", 3 ], [ writing.status, writing.sources.size ]
    assert_equal "Patience", writing.section(:quality)["name"]

    # This week's listening game in the Rivera Family, from the saved reply, with the pages it used (12_listening_games.rb).
    game = rivera.listening_games.sole
    assert_equal monday, game.week_of
    assert_equal({ "talk" => 5, "spiritual_gems" => 2, "bible_reading" => 1, "congregation_bible_study" => 6 }, game.rounds.map(&:step).tally)
    assert_equal 3, game.sources.count
    # Lucia found its first Treasures round, so her Treasures step opens at the second.
    assert_equal [ game.rounds.first.answer.label ], user("lucia.rivera").meeting_notes.find_by!(kind: "midweek", week_of: monday).finds_for("talk").map(&:label)
    # Last week's shared helper note has her finds and the answer she gave.
    shared = user("lucia.rivera").meeting_notes.find_by!(week_of: monday - 1.week)
    assert_equal [ 3, 7 ], [ shared.found_count, shared.answer.paragraph ]
    assert shared.marked?("congregation_bible_study")

    # This week's Get ready cards in the Rivera Family, from the saved reply, with the pages it used (13_prep_weeks.rb).
    prep_week = rivera.prep_week_for(monday)
    assert_equal PrepWeek::Card::STEPS.keys, prep_week.cards.map(&:step)
    assert_equal [ "Lamentations 1–2", 4 ], [ prep_week.cards.second.reading, prep_week.cards.second.story.size ]
    assert_equal 3, prep_week.sources.size

    # Daniel's study guide for this week in the Riveras' time zone, with his setting on, from the saved reply, with the
    # pages it used (14_study_guides.rb).
    daniel_rivera = user("daniel.rivera@example.com")
    assert rivera.memberships.find_by!(user: daniel_rivera).adult?
    assert daniel_rivera.study_guide_on?
    guide = daniel_rivera.study_guide_for(monday)
    assert_equal StudyGuide::Part::STEPS.keys, guide.parts.map(&:step)
    assert_equal "Lamentations 1–2", guide.parts.find { it.step == "bible_reading" }.content["reading"]
    assert_equal 4, guide.sources.size

    assert_equal 0, Ai::Use.count
  end

  test "a second run adds nothing" do
    freeze_time
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
