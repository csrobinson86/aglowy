require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "squishes the name" do
    assert_equal "Ann Lee", User.new(name: "  Ann   Lee ").name
  end

  test "first_name is the first word of the name" do
    assert_equal "Hannah", users(:head).first_name
    assert_equal "Cher", User.new(name: "Cher").first_name
  end

  test "requires a name" do
    user = User.new(name: " ")

    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "time_zone is a known zone or unset" do
    assert User.new(name: "Ann", time_zone: "Central Time (US & Canada)").valid?
    assert_nil User.new(name: "Ann", time_zone: "").time_zone

    user = User.new(name: "Ann", time_zone: "Atlantis")
    assert_not user.valid?
    assert_includes user.errors[:time_zone], "is not included in the list"
  end

  test "a new user's appearance is auto" do
    assert_equal "auto", User.new(name: "Ann").appearance
    assert_equal "auto", User.create!(name: "Ann").reload.appearance
  end

  test "appearance sepia is invalid" do
    user = User.new(name: "Ann", appearance: "sepia")

    assert_not user.valid?
    assert_includes user.errors[:appearance], "is not included in the list"
  end

  test "active_household finds one of the person's active households by id, and nothing else" do
    assert_equal households(:home), users(:head).active_household(households(:home).id)
    assert_nil users(:former).active_household(households(:home).id)
    assert_nil users(:head).active_household(households(:other).id)
    assert_nil users(:head).active_household("not-a-uuid")
    assert_nil users(:head).active_household(nil)
  end

  test "active_households excludes households where the membership is inactive" do
    assert_equal [ households(:home), households(:parents) ].sort_by(&:id), users(:head).active_households.sort_by(&:id)
    assert_empty users(:former).active_households
  end

  # users(:head) is Maria in the frames; users(:eli) is Eli, a child in one household.
  test "can_start_household? is true for Maria" do
    assert users(:head).can_start_household?
  end

  test "can_start_household? is false for Eli" do
    assert_not users(:eli).can_start_household?
  end

  test "can_start_household? is true for someone who's a child in one household and an adult in another" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :adult)

    assert users(:eli).can_start_household?
  end

  test "can_start_household? is true for an adult whose only membership is inactive" do
    assert_equal [ [ "adult", false ] ], users(:former).memberships.map { [ it.role, it.active ] }

    assert users(:former).can_start_household?
  end

  test "can_start_household? is false for a child whose only membership is inactive" do
    memberships(:eli_in_home).update!(active: false)

    assert_not users(:eli).can_start_household?
  end

  test "can_start_household? is true for someone with no memberships yet" do
    assert_empty users(:newcomer).memberships

    assert users(:newcomer).can_start_household?
  end

  test "child_in_every_household? is true for a child in one household, and in two" do
    assert users(:eli).child_in_every_household?

    Membership.create!(user: users(:eli), household: households(:parents), role: :child)
    assert users(:eli).child_in_every_household?
  end

  test "child_in_every_household? is false once an active seat anywhere is an adult's" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :adult)

    assert_not users(:eli).child_in_every_household?
  end

  test "child_in_every_household? is false once an active seat anywhere is a head's" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :head)

    assert_not users(:eli).child_in_every_household?
  end

  test "child_in_every_household? is true again when the adult seat is inactive" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :adult, active: false)

    assert users(:eli).child_in_every_household?
  end

  test "give_login makes a confirmed username-only login whose password nobody knows" do
    identity = users(:sofia).give_login(username: "Sofia.Rivera")

    assert identity.persisted?
    assert_equal "sofia.rivera", identity.username
    assert_nil identity.email
    assert identity.confirmed?
    assert identity.encrypted_password.present?
    assert_not identity.valid_password?("")
  end

  test "give_login with a taken username returns the unsaved login with the error" do
    identity = users(:sofia).give_login(username: "eli.rivera")

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "has already been taken"
  end

  # Two people choosing one username at once both pass the uniqueness check in Ruby; the unique index stops the second.
  test "give_login that loses the race for a username returns the unsaved login with the error, not an exception" do
    uniqueness = Identity.validators_on(:username).grep(ActiveRecord::Validations::UniquenessValidator).sole
    uniqueness.define_singleton_method(:validate) { |_record| }

    identity = assert_no_difference(-> { Identity.count }) { users(:sofia).give_login(username: "eli.rivera") }

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "has already been taken"
  ensure
    uniqueness.singleton_class.remove_method(:validate)
  end

  # Two submissions of the form at once both pass give_login? before either saves; identities.user_id stops the second.
  test "give_login for someone who got a login a moment ago returns the unsaved login with the error, not an exception" do
    identity = assert_no_difference(-> { Identity.count }) { users(:eli).give_login(username: "eli.second") }

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "wasn't saved: Eli already has a login"
  end

  test "database: a user without a name raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      User.insert!({ name: nil })
    end
  end

  test "database: an appearance other than auto, light or dark raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      users(:head).update_column(:appearance, "sepia")
    end
  end

  test "database: an avatar color outside the palette raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      users(:head).update_column(:avatar_color, "red")
    end
  end

  test "everyone starts blue" do
    assert_equal "blue", User.create!(name: "Nadia New").avatar_color
  end

  test "change_avatar_color saves a color from the palette" do
    assert users(:eli).change_avatar_color("green")

    assert_equal "green", users(:eli).reload.avatar_color
  end

  test "change_avatar_color refuses a color outside the palette and saves nothing" do
    assert_not users(:eli).change_avatar_color("red")

    assert_includes users(:eli).errors[:avatar_color], "is not included in the list"
    assert_equal "blue", users(:eli).reload.avatar_color
  end

  test "accepted_ai_terms? is false with no acceptance" do
    assert_not users(:head).accepted_ai_terms?
  end

  test "accepted_ai_terms? is false with only an older version accepted" do
    Ai::Acceptance.create!(user: users(:head), version: Rails.configuration.x.ai.terms_version - 1, understood: "1")

    assert_not users(:head).accepted_ai_terms?
  end

  test "accepted_ai_terms? is true at the current version" do
    Ai::Acceptance.create!(user: users(:head), version: Rails.configuration.x.ai.terms_version, understood: "1")

    assert_predicate users(:head), :accepted_ai_terms?
  end

  test "may_ask_study_ai? for a child with a grant in one of two households" do
    Membership.create!(household: households(:parents), user: users(:eli), role: :child)
    assert_not users(:eli).may_ask_study_ai?

    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert users(:eli).reload.may_ask_study_ai?
  end

  test "personal_study_read_by_heads? while any of their child seats has a grant" do
    assert_not users(:eli).personal_study_read_by_heads?

    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert users(:eli).personal_study_read_by_heads?
    assert_not users(:head).personal_study_read_by_heads?
  end

  # Bookmarks (docs/design/bookmarks.md, User). The study's sources are what Aglowy showed the person.
  ARTICLE = { "url" => "https://www.jw.org/en/library/books/bible-questions-answered/", "title" => "Bible Questions Answered" }.freeze

  def study_with_article
    personal_studies(:head_suffering).tap do |study|
      personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "One." ] }, sources: [ ARTICLE ])
    end
  end

  test "bookmark takes the title from the study's sources" do
    bookmark = users(:head).bookmark(url: "#{ARTICLE["url"]}#top", source: study_with_article)

    assert bookmark.persisted?
    assert_equal ARTICLE["url"], bookmark.url
    assert_equal "Bible Questions Answered", bookmark.title
    assert_equal personal_studies(:head_suffering), bookmark.source
  end

  test "bookmark refuses a URL that isn't in the study's sources" do
    study = study_with_article

    assert_no_difference -> { Bookmark.count } do
      bookmark = users(:head).bookmark(url: "https://www.jw.org/en/whats-new/", source: study)

      assert_not bookmark.persisted?
      assert_includes bookmark.errors[:url], "isn't one of the pages in this study"
    end
  end

  test "bookmarking a saved page again finds the first bookmark" do
    study = study_with_article
    first = users(:head).bookmark(url: ARTICLE["url"], source: study)

    assert_no_difference -> { Bookmark.count } do
      assert_equal first, users(:head).bookmark(url: "#{ARTICLE["url"]}?utm_source=x", source: study)
    end
  end

  test "bookmark cuts a long title to 120 characters" do
    study = personal_studies(:head_suffering)
    personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "One." ] }, sources: [ ARTICLE.merge("title" => "x" * 200) ])

    assert_equal 120, users(:head).bookmark(url: ARTICLE["url"], source: study).title.size
  end

  test "bookmark_for finds the person's own bookmark for a page or a scripture" do
    scripture = users(:head).bookmarks.create!(scripture: "19:23:4")
    page = bookmarks(:head_suffering_article)

    assert_equal page, users(:head).bookmark_for(url: "#{page.url}#top")
    assert_equal scripture, users(:head).bookmark_for(scripture: "19:23:4")
    assert_nil users(:spouse).bookmark_for(url: page.url)
    assert_nil users(:head).bookmark_for(url: "https://example.com/")
    assert_nil users(:head).bookmark_for
  end

  test "bookmarked holds the saved URLs in one query" do
    users(:head).bookmarks.create!(scripture: "19:23:4")
    page = bookmarks(:head_suffering_article)

    bookmarked = assert_queries_count(1) { users(:head).bookmarked }

    assert bookmarked.include?(page.url)
    assert bookmarked.include?("19:23:4")
    assert_not bookmarked.include?(bookmarks(:spouse_ransom_article).url)
    assert_equal page.id, bookmarked[page.url]
  end

  test "bookmark saves a scripture the study's answers link" do
    study = personal_studies(:head_suffering)
    personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "Comfort (Revelation 21:3, 4)." ] })

    bookmark = users(:head).bookmark(scripture: "66:21:3-4", source: study)

    assert bookmark.persisted?
    assert_equal "66:21:3-4", bookmark.scripture
    assert_nil bookmark.title
    assert_equal study, bookmark.source
    assert_no_difference(-> { Bookmark.count }) { assert_equal bookmark, users(:head).bookmark(scripture: "66:21:3-4", source: study) }
  end

  # A note can link a whole chapter with the picker, so a chapter can be bookmarked from a note.
  test "bookmark saves a scripture the note links, a whole chapter too" do
    note = personal_notes(:head_return_visit)
    note.body = %(<p>Psalm 83:18</p>#{ActionText::Attachment.from_attachable(Bible::Reference.find("19:23")).to_html})
    note.link_scriptures
    note.save!

    assert users(:head).bookmark(scripture: "19:83:18", source: note).persisted?
    chapter = users(:head).bookmark(scripture: "19:23", source: note)

    assert chapter.persisted?
    assert_equal "19:23", chapter.scripture
  end

  test "bookmarking a scripture that isn't in the source is refused" do
    study = personal_studies(:head_suffering)
    personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "Comfort (Revelation 21:4)." ] })

    assert_no_difference -> { Bookmark.count } do
      [ "19:23:4", "19:23:99", "Psalm 23" ].each do |scripture|
        bookmark = users(:head).bookmark(scripture:, source: study)

        assert_not bookmark.persisted?, scripture
        assert_includes bookmark.errors[:scripture], "isn't one of the scriptures in this study or note"
      end
    end
  end

  test "bookmarked includes scripture ids" do
    study = personal_studies(:head_suffering)
    personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "Comfort (Revelation 21:3, 4)." ] })
    bookmark = users(:head).bookmark(scripture: "66:21:3-4", source: study)

    assert_equal bookmark.id, users(:head).bookmarked["66:21:3-4"]
  end

  test "deleting a person deletes their bookmarks" do
    user = User.create!(name: "Ann")
    user.bookmarks.create!(url: ARTICLE["url"])

    assert_difference -> { Bookmark.count }, -1 do
      user.destroy!
    end
  end

  test "households_seeing_times: only the active households they share with" do
    memberships(:head_in_parents).share_times

    assert_equal [ households(:parents) ], users(:head).households_seeing_times.to_a
  end

  test "notify twice with one key makes one notification and delivers it once" do
    note = meeting_notes(:head_midweek)

    assert_enqueued_jobs 1, only: Notification::DeliveryJob do
      2.times { users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: note, actor: users(:head), dedupe_key: "shared_with_you:1") }
    end

    assert_equal 1, users(:spouse).notifications.count
  end

  test "notify broadcasts the new count once: its counter and its name" do
    assert_turbo_stream_broadcasts [ users(:spouse), :notifications ], count: 2 do
      users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: meeting_notes(:head_midweek), actor: users(:head), dedupe_key: "shared_with_you:1")
    end
  end

  test "notify inside a transaction broadcasts the count only once it commits, so a rollback publishes nothing" do
    broadcasts = -> { capture_turbo_stream_broadcasts([ users(:spouse), :notifications ]).size }

    assert_no_difference broadcasts do
      Notification.transaction do
        users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: meeting_notes(:head_midweek), actor: users(:head), dedupe_key: "shared_with_you:1")
        raise ActiveRecord::Rollback
      end
    end
    assert_not Notification.exists?(user: users(:spouse))

    before = broadcasts.call
    assert_difference broadcasts, 2 do
      Notification.transaction do
        users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: meeting_notes(:head_midweek), actor: users(:head), dedupe_key: "shared_with_you:1")
        assert_equal before, broadcasts.call, "not before the commit"
      end
    end
  end

  test "read_all_notifications reads only visible unread ones" do
    note = meeting_notes(:head_midweek)
    unread = users(:head).notify(kind: "shared_with_you", household: households(:home), subject: note, actor: users(:spouse), dedupe_key: "shared_with_you:1")
    already_read = users(:head).notify(kind: "shared_with_you", household: households(:home), subject: meeting_notes(:head_weekend), actor: users(:spouse), dedupe_key: "shared_with_you:2")
    hidden = users(:head).notify(kind: "shared_with_you", household: households(:parents), subject: goals(:spouse_bible_reading), actor: users(:grandparent), dedupe_key: "shared_with_you:3")
    someone_elses = users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: note, actor: users(:head), dedupe_key: "shared_with_you:1")
    already_read.read
    read_at = already_read.reading.created_at
    memberships(:head_in_parents).deactivate

    read_all_at = travel 1.minute do
      assert_turbo_stream_broadcasts([ users(:head), :notifications ], count: 2) { users(:head).read_all_notifications }
      Time.current
    end

    assert_equal 7, unread.reload.reading.id[14].to_i, "a UUIDv7 id"
    assert_equal read_all_at, unread.reading.created_at
    assert_equal read_at, already_read.reload.reading.created_at
    assert_nil hidden.reload.reading
    assert_nil someone_elses.reload.reading
    assert_equal 0, users(:head).unread_notifications_count
  end

  test "read_all_notifications with nothing unread reads nothing" do
    assert_no_difference -> { Notification::Reading.count } do
      users(:head).read_all_notifications
    end
  end

  test "emailable? is false for a child, even with an email address, and for a username-only login" do
    Identity.create!(user: users(:sofia), email: "sofia@example.com", password: "password123", confirmed_at: Time.current)
    identities(:spouse).update_columns(email: nil, username: "sam.spouse")

    assert users(:head).emailable?
    assert_not users(:sofia).emailable?, "a child with an email address"
    assert_not users(:eli).emailable?, "a child with a username"
    assert_not users(:spouse).reload.emailable?, "an adult with a username-only login"
    assert_not users(:child).emailable?, "no login at all"
  end

  test "emailable? is false for a child in any active household, and true again once they've left it" do
    households(:parents).memberships.create!(user: users(:spouse), role: :child)
    assert_not users(:spouse).emailable?

    users(:spouse).memberships.find_by!(household: households(:parents)).update!(active: false)
    assert users(:spouse).emailable?
  end

  test "quiet_now? across midnight in the person's zone" do
    head = users(:head)
    head.update!(time_zone: "Central Time (US & Canada)")
    chicago = ActiveSupport::TimeZone[head.time_zone]

    { [ 22, 20, 59 ] => false, [ 22, 21, 0 ] => true, [ 22, 23, 59 ] => true, [ 23, 0, 0 ] => true, [ 23, 6, 59 ] => true, [ 23, 7, 0 ] => false, [ 23, 12, 0 ] => false }.each do |(day, hour, minute), quiet|
      travel_to chicago.local(2026, 11, day, hour, minute)

      assert_equal quiet, head.quiet_now?, "#{hour}:#{minute} in Chicago"
    end

    # 9:30 PM in Chicago is 3:30 AM the next day in UTC: the zone decides, not the server's clock.
    travel_to Time.utc(2026, 11, 23, 3, 30)
    assert head.quiet_now?
    head.update!(time_zone: "UTC")
    assert head.quiet_now?
    head.update!(time_zone: "Hawaii")
    assert_not head.quiet_now?, "5:30 PM in Hawaii"
  end

  test "quiet_now? with quiet hours inside one day, and none when they start and end together" do
    head = users(:head)
    head.update!(time_zone: "UTC", quiet_hours_start: "13:00", quiet_hours_end: "14:30")

    travel_to Time.utc(2026, 11, 23, 14, 29)
    assert head.quiet_now?
    travel_to Time.utc(2026, 11, 23, 14, 30)
    assert_not head.quiet_now?

    head.update!(quiet_hours_start: "14:30")
    assert_not head.quiet_now?
  end

  test "quiet_hours_end_after and last_quiet_hours_end_before are the ends on either side, in the person's zone" do
    head = users(:head)
    head.update!(time_zone: "Central Time (US & Canada)")
    chicago = ActiveSupport::TimeZone[head.time_zone]

    assert_equal chicago.local(2026, 11, 23, 7), head.quiet_hours_end_after(chicago.local(2026, 11, 22, 22))
    assert_equal chicago.local(2026, 11, 23, 7), head.quiet_hours_end_after(chicago.local(2026, 11, 23, 6, 59))
    assert_equal chicago.local(2026, 11, 24, 7), head.quiet_hours_end_after(chicago.local(2026, 11, 23, 7))

    assert_equal chicago.local(2026, 11, 22, 7), head.last_quiet_hours_end_before(chicago.local(2026, 11, 23, 6, 59))
    assert_equal chicago.local(2026, 11, 23, 7), head.last_quiet_hours_end_before(chicago.local(2026, 11, 23, 7))
    assert_equal chicago.local(2026, 11, 23, 7), head.last_quiet_hours_end_before(chicago.local(2026, 11, 23, 23))
  end

  test "quiet_now? reads the time it's given, so a caller can ask about one moment" do
    head = users(:head)
    head.update!(time_zone: "Central Time (US & Canada)")
    chicago = ActiveSupport::TimeZone[head.time_zone]
    travel_to chicago.local(2026, 11, 23, 12)

    assert head.quiet_now?(chicago.local(2026, 11, 23, 6, 59, 59))
    assert_not head.quiet_now?(chicago.local(2026, 11, 23, 7))
  end

  # Sunday, November 1, 2026 in Chicago: 2 AM goes back to 1 AM, so 1:30 AM comes twice, at 6:30 and 7:30 UTC.
  test "quiet hours that end in the hour the clocks go back over end both times it comes" do
    head = users(:head)
    head.update!(time_zone: "Central Time (US & Canada)", quiet_hours_end: "01:30")
    first, second = Time.utc(2026, 11, 1, 6, 30), Time.utc(2026, 11, 1, 7, 30)

    assert head.quiet_now?(Time.utc(2026, 11, 1, 6, 15))
    assert_equal first, head.quiet_hours_end_after(Time.utc(2026, 11, 1, 6, 15))
    assert head.quiet_now?(Time.utc(2026, 11, 1, 7, 15)), "the second 1:15 AM"
    assert_equal second, head.quiet_hours_end_after(Time.utc(2026, 11, 1, 7, 15))
    assert_equal second, head.quiet_hours_end_after(first)
    assert_equal Time.utc(2026, 11, 2, 7, 30), head.quiet_hours_end_after(second)

    assert_equal first, head.last_quiet_hours_end_before(Time.utc(2026, 11, 1, 7, 15))
    assert_equal second, head.last_quiet_hours_end_before(Time.utc(2026, 11, 1, 12))
  end

  # Sunday, March 8, 2026 in Chicago: 2 AM goes forward to 3 AM, so there is no 2:30 AM and they end at 3:30.
  test "quiet hours that end in the hour the clocks go forward over end once, an hour on" do
    head = users(:head)
    head.update!(time_zone: "Central Time (US & Canada)", quiet_hours_end: "02:30")

    assert_equal Time.utc(2026, 3, 8, 8, 30), head.quiet_hours_end_after(Time.utc(2026, 3, 8, 7))
    assert_equal Time.utc(2026, 3, 9, 7, 30), head.quiet_hours_end_after(Time.utc(2026, 3, 8, 8, 30))
  end

  test "quiet hours default to 9 PM until 7 AM and are on the half hour" do
    head = users(:head)

    assert_equal %w[ 21:00 07:00 ], [ head.quiet_hours_start, head.quiet_hours_end ].map { it.strftime("%H:%M") }
    assert head.update(quiet_hours_start: "22:30", quiet_hours_end: "06:30")
    assert_not head.update(quiet_hours_start: "22:10")
    assert_includes head.errors[:quiet_hours_start], "must be on the hour or the half hour"
    assert_not head.update(quiet_hours_start: "22:00", quiet_hours_end: "")
    assert_includes head.errors[:quiet_hours_end], "can't be blank"
  end

  test "database: quiet hours off the half hour raise CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      users(:head).update_column(:quiet_hours_end, "07:10")
    end
  end

  test "notification_kinds: everyone gets the weekly preview and shared, heads and adults the invitation and go-bag kinds, heads the topic kind" do
    assert_equal %w[ weekly_preview study_topic_needed shared_with_you invitation_unaccepted go_bag_use_by ], users(:head).notification_kinds.map(&:name)
    assert_equal %w[ weekly_preview shared_with_you invitation_unaccepted go_bag_use_by ], users(:spouse).notification_kinds.map(&:name)
    assert_equal %w[ weekly_preview shared_with_you ], users(:eli).notification_kinds.map(&:name)
    assert_equal %w[ weekly_preview shared_with_you ], users(:former).notification_kinds.map(&:name), "roles in a household they left don't count"
  end

  test "an unsubscribe token finds its person only for its own scope" do
    head = users(:head)

    assert_equal head, User.find_by_unsubscribe_token("summary", head.unsubscribe_token("summary"))
    assert_nil User.find_by_unsubscribe_token("weekly_preview", head.unsubscribe_token("summary"))
    assert_nil User.find_by_unsubscribe_token("shared_with_you", head.generate_token_for(:unsubscribe_summary)), "not a scope"
    assert_nil User.find_by_unsubscribe_token("summary", "nonsense")
  end

  test "unsubscribe_from_email turns off one right-away kind, or every summary kind, and leaves the rest" do
    head = users(:head)
    everything = Notification::Kind.all.map { [ it.name, "email" ] }

    head.notification_settings.change(everything)
    head.unsubscribe_from_email("weekly_preview")
    assert_equal %w[ go_bag_use_by invitation_unaccepted shared_with_you study_topic_needed ], head.notification_settings.pluck(:kind).sort

    head.unsubscribe_from_email("summary")
    assert_equal %w[ study_topic_needed ], head.notification_settings.pluck(:kind)
  end

  # Meeting parts with AI (docs/design/meeting-parts.md, Who can do what): parts are personal, so any household counts.
  test "may_prepare_parts_with_ai? for a head and an adult, not a child, and a child here who is an adult elsewhere" do
    assert users(:head).may_prepare_parts_with_ai?
    assert users(:spouse).may_prepare_parts_with_ai?
    assert_not users(:eli).may_prepare_parts_with_ai?
    assert_not users(:former).may_prepare_parts_with_ai?, "an adult who left has no active seat"

    Membership.create!(household: households(:parents), user: users(:eli), role: :adult)

    assert users(:eli).may_prepare_parts_with_ai?
  end

  test "may_have_daily_brief? for a head and an adult, not a child, and a child here who is an adult elsewhere" do
    assert users(:head).may_have_daily_brief?
    assert users(:spouse).may_have_daily_brief?
    assert_not users(:eli).may_have_daily_brief?
    assert_not users(:former).may_have_daily_brief?, "an adult who left has no active seat"

    Membership.create!(household: households(:parents), user: users(:eli), role: :adult)

    assert users(:eli).may_have_daily_brief?
  end
  # The weekly study guide job's clock (docs/design/study-guide.md, The weekly job; Trap 6): limit_time_zone's zone.
  test "at_local_hour by the person's own zone, else their oldest active household's, else UTC" do
    households(:home).update!(time_zone: "Auckland")
    users(:spouse).update!(time_zone: "Eastern Time (US & Canada)")
    # Monday 16 November 2026: 3am in UTC, 4pm in Auckland, 10pm on Sunday in New York.
    now = Time.utc(2026, 11, 16, 3)

    at_three = User.at_local_hour(3, now:)
    assert_includes at_three, users(:outsider), "no zone of their own, and their household's is UTC"
    assert_not_includes at_three, users(:head), "their oldest active household is in Auckland"
    assert_not_includes at_three, users(:spouse)

    assert_includes User.at_local_hour(16, now:), users(:head)
    assert_includes User.at_local_hour(22, now:), users(:spouse)
    assert_includes User.at_local_hour(3, now:), users(:staff), "no zone and no household is UTC"
  end

  test "at_local_hour skips an inactive membership's household, as limit_time_zone does" do
    households(:home).update!(time_zone: "Auckland")
    now = Time.utc(2026, 11, 16, 3)

    assert_equal "Auckland", users(:head).limit_time_zone
    assert_includes User.at_local_hour(16, now:), users(:head)
    assert_includes User.at_local_hour(3, now:), users(:former), "their only seat is inactive, so UTC"

    users(:head).memberships.find_by!(household: households(:home)).update_column(:active, false)

    assert_equal "UTC", users(:head).reload.limit_time_zone
    assert_includes User.at_local_hour(3, now:), users(:head), "the parents household, in UTC, is the only active one"
  end
end
