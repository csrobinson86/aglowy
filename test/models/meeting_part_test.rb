require "test_helper"

class MeetingPartTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def new_part(**attributes)
    users(:head).meeting_parts.new(kind: "following_up", meeting_on: Date.new(2026, 12, 3), minutes: 4, topic: "Return to someone who asked about prayer.", **attributes)
  end

  test "valid with a kind, date, minutes and topic; each is required" do
    assert new_part.valid?

    { kind: nil, meeting_on: nil, minutes: nil, topic: " " }.each do |attribute, value|
      part = new_part(attribute => value)
      assert_not part.valid?, "expected no #{attribute} to be refused"
      assert part.errors[attribute].any?
    end
  end

  test "kind is one of the six, minutes 1 to 15, setting one of the three or none" do
    assert_not new_part(kind: "bible_reading").valid?
    [ 0, 16, 2.5 ].each { assert_not new_part(minutes: it).valid?, "expected #{it} minutes to be refused" }
    [ 1, 15 ].each { assert new_part(minutes: it).valid? }
    assert_not new_part(setting: "on_the_phone").valid?
    assert_nil new_part(setting: "").tap(&:validate).setting
    MeetingPart::SETTINGS.each_key { assert new_part(setting: it).valid? }
  end

  test "topic is 300 characters at most, study point and assistant 80, counsel 2,000" do
    assert new_part(topic: "x" * 300, study_point: "x" * 80, assistant: "x" * 80, counsel: "x" * 2000).valid?

    { topic: 301, study_point: 81, assistant: 81, counsel: 2001 }.each do |attribute, length|
      part = new_part(attribute => "x" * length)
      assert_not part.valid?, "expected a #{length}-character #{attribute} to be refused"
      assert part.errors[attribute].any?
    end
  end

  test "blank optional fields are saved as nothing" do
    part = new_part(study_point: " ", assistant: "", counsel: " \n ")
    part.save!

    assert_nil part.study_point
    assert_nil part.assistant
    assert_nil part.counsel
  end

  test "coming_up and earlier split on today, in order" do
    today = Date.new(2026, 11, 17)
    MeetingPart.delete_all
    head = users(:head)
    later = new_part(meeting_on: today + 14).tap(&:save!)
    on_today = new_part(meeting_on: today).tap(&:save!)
    soon = new_part(meeting_on: today + 2).tap(&:save!)
    yesterday = new_part(meeting_on: today - 1).tap(&:save!)
    long_ago = new_part(meeting_on: today - 60).tap(&:save!)

    assert_equal [ on_today, soon, later ], head.meeting_parts.coming_up(today).to_a
    assert_equal [ yesterday, long_ago ], head.meeting_parts.earlier(today).to_a
  end

  test "week_of is that week's Monday" do
    assert_equal Date.new(2026, 11, 30), new_part(meeting_on: Date.new(2026, 12, 3)).week_of
    assert_equal Date.new(2026, 11, 30), new_part(meeting_on: Date.new(2026, 11, 30)).week_of
    assert_equal Date.new(2026, 11, 30), new_part(meeting_on: Date.new(2026, 12, 6)).week_of
  end

  test "program_url is that week's program on wol.jw.org" do
    assert_equal "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/49", new_part(meeting_on: Date.new(2026, 12, 3)).program_url
  end

  test "references in the preparation become scripture links on save" do
    part = meeting_parts(:head_conversation)
    part.preparation = "<p>Read Psalm 37:10, 11 and say what I like about it.</p>"

    part.link_scriptures
    part.save!

    assert_equal [ Bible::Reference.find("19:37:10-11") ], part.reload.preparation.body.attachables
  end

  test "spoken_length is the preparation's plain text, with nothing when there's no preparation" do
    part = meeting_parts(:head_conversation)
    assert_nil part.spoken_length.seconds

    part.update!(preparation: "<ul><li>#{([ "word" ] * 54).join(" ")}</li><li>#{([ "word" ] * 54).join(" ")}</li></ul>")

    assert_equal 50, part.reload.spoken_length.seconds
  end

  test "spoken_length counts the words as the editor has them: no list numbers, and headings and table cells apart" do
    part = meeting_parts(:head_conversation)

    # 100 words; ActionText's plain text adds "1." to "20." for 120, which is 60 s.
    part.update!(preparation: "<ol>#{"<li>word word word word word</li>" * 20}</ol>")
    assert_equal 50, part.reload.spoken_length.seconds

    # 60 words; ActionText's plain text runs each heading into its paragraph, "PointWord", for 30, which is 10 s.
    part.update!(preparation: "<h3>Point</h3><p>Word</p>" * 30)
    assert_equal 30, part.reload.spoken_length.seconds

    # 60 words; ActionText's plain text runs the cells together into one.
    part.update!(preparation: "<table><tr>#{"<td>cell cell</td>" * 30}</tr></table>")
    assert_equal 30, part.reload.spoken_length.seconds
  end

  test "the preparation can only hold scripture links" do
    part = meeting_parts(:head_conversation)
    part.preparation = "<p>A cat</p>#{remote_image_attachment}"

    assert_not part.valid?
    assert_equal [ "can only link scriptures" ], part.errors[:preparation]
  end

  test "topic, study_point, assistant, counsel and the preparation are encrypted at rest" do
    part = meeting_parts(:head_conversation)
    part.update!(counsel: "Good eye contact; work on a warmer close", preparation: "<p>Say hi to Leo at lunch</p>")

    raw = MeetingPart.connection.select_one(MeetingPart.where(id: part.id).select(:topic, :study_point, :assistant, :counsel).to_sql)
    assert_not_includes raw["topic"], "hope for the future"
    assert_not_includes raw["study_point"], "lesson 1"
    assert_not_includes raw["assistant"], "Ana"
    assert_not_includes raw["counsel"], "eye contact"

    rich_text = ActionText::RichText.connection.select_value(ActionText::RichText.where(record: part, name: "preparation").select(:body).to_sql)
    assert_not_includes rich_text, "Leo"
    assert_includes part.reload.preparation.to_plain_text, "Say hi to Leo at lunch"
  end

  test "label and detail come from the kind" do
    part = new_part(kind: "explaining_beliefs_talk")

    assert_equal "Explaining Your Beliefs", part.kind_details.label
    assert_equal "Talk", part.kind_details.detail
    assert_equal "Informal witnessing", new_part(setting: "informal_witnessing").setting_label
    assert_nil new_part.setting_label
  end

  test "deleting the person deletes their parts" do
    part = users(:newcomer).meeting_parts.create!(kind: "talk", meeting_on: Date.new(2026, 12, 3), minutes: 5, topic: "Why we can trust the Bible",
                                                  preparation: "<p>Start with 2 Timothy 3:16</p>")

    users(:newcomer).destroy!

    assert_not MeetingPart.exists?(part.id)
    assert_not ActionText::RichText.exists?(record: part)
  end

  test "database: a kind outside the six raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_parts(:head_conversation).update_column(:kind, "bible_reading") }
  end

  test "database: a setting outside the three raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_parts(:head_conversation).update_column(:setting, "on_the_phone") }
  end

  test "database: no setting is allowed" do
    assert meeting_parts(:head_conversation).update_column(:setting, nil)
  end

  test "database: 0 minutes raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_parts(:head_conversation).update_column(:minutes, 0) }
  end

  test "database: 16 minutes raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_parts(:head_conversation).update_column(:minutes, 16) }
  end

  test "database: a part without a user raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_parts(:head_conversation).update_column(:user_id, nil) }
  end

  test "database: a part without a kind raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_parts(:head_conversation).update_column(:kind, nil) }
  end

  test "database: a part without a meeting date raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_parts(:head_conversation).update_column(:meeting_on, nil) }
  end

  test "database: a part without minutes raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_parts(:head_conversation).update_column(:minutes, nil) }
  end

  test "database: a part without a topic raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_parts(:head_conversation).update_column(:topic, nil) }
  end

  test "database: a user that doesn't exist raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      MeetingPart.insert!({ user_id: SecureRandom.uuid_v7, kind: "talk", meeting_on: Date.current, minutes: 5, topic: "x" })
    end
  end

  # Sharing (docs/design/meeting-parts.md, MeetingPart; docs/design/meeting-notes.md, MeetingNote::Sharing).
  test "share_with shares into a household the owner is active in, and tells the other members" do
    part = meeting_parts(:head_conversation)

    part.share_with(households(:home))

    assert_equal [ households(:home) ], part.shared_households
    assert part.shared_with?(households(:home))
    assert_equal users(:spouse, :child, :eli, :sofia).map(&:id).sort, Notification.where(subject: part).pluck(:user_id).sort
  end

  test "sharing twice leaves one record and one notification each" do
    part = meeting_parts(:head_conversation)

    assert_difference -> { MeetingPart::Sharing.count } => 1, -> { Notification.where(subject: part).count } => 4 do
      part.share_with(households(:home))
      part.share_with(households(:home))
    end
  end

  test "sharing with a household the owner isn't in raises RecordNotFound" do
    assert_raises(ActiveRecord::RecordNotFound) { meeting_parts(:head_conversation).share_with(households(:other)) }
    assert_empty MeetingPart::Sharing.all
  end

  test "stop_sharing_with ends the share in that household only, and withdraws its notifications there" do
    part = meeting_parts(:head_conversation)
    part.share_with(households(:home))
    part.share_with(households(:parents))

    part.stop_sharing_with(households(:home))

    assert_equal [ households(:parents) ], part.shared_households
    assert_equal [ households(:parents).id ], Notification.where(subject: part).distinct.pluck(:household_id)
  end

  test "shared_with is the parts shared there by an owner still active there" do
    meeting_parts(:head_conversation).share_with(households(:home))
    meeting_parts(:spouse_talk).share_with(households(:home))
    meeting_parts(:head_disciples).share_with(households(:parents))

    assert_equal meeting_parts(:head_conversation, :spouse_talk).sort_by(&:id), MeetingPart.shared_with(households(:home)).sort_by(&:id)
    assert_equal [ meeting_parts(:head_disciples) ], MeetingPart.shared_with(households(:parents)).to_a
  end

  test "shared_with leaves out a part whose owner is inactive there, even with its sharing still there" do
    meeting_parts(:spouse_talk).share_with(households(:home))
    memberships(:spouse_in_home).update_column(:active, false)

    assert_equal 1, MeetingPart::Sharing.count
    assert_empty MeetingPart.shared_with(households(:home))
  end

  test "deleting a part deletes its sharings and notifications" do
    part = meeting_parts(:head_conversation)
    part.share_with(households(:home))

    part.destroy!

    assert_empty MeetingPart::Sharing.where(meeting_part_id: part.id)
    assert_empty Notification.where(subject_type: "MeetingPart", subject_id: part.id)
  end

  test "database: a second sharing of one part with one household raises RecordNotUnique" do
    meeting_parts(:head_conversation).share_with(households(:home))

    assert_raises(ActiveRecord::RecordNotUnique) do
      MeetingPart::Sharing.insert!({ meeting_part_id: meeting_parts(:head_conversation).id, household_id: households(:home).id })
    end
  end

  test "database: deleting a part deletes its sharings" do
    part = meeting_parts(:head_conversation)
    part.share_with(households(:home))

    MeetingPart.where(id: part).delete_all

    assert_empty MeetingPart::Sharing.all
  end

  # Prepare with AI (docs/design/meeting-parts.md, How a request runs). The test queue adapter only enqueues the job.
  test "draft makes an outline draft with its own chat and its use, and queues MeetingPart::WriteDraftJob once" do
    users(:head).accept_ai_terms(understood: "1")
    part = meeting_parts(:head_conversation)
    draft = nil

    assert_enqueued_jobs 1, only: MeetingPart::WriteDraftJob do
      draft = part.draft(kind: "outline", request: "The person is busy.", by: users(:head))
    end

    assert_predicate draft, :persisted?
    assert_equal [ "outline", "drafting", "The person is busy.", users(:head) ], [ draft.kind, draft.status, draft.request, draft.user ]
    assert_equal [ "meeting_part", users(:head), nil ], [ draft.chat.purpose, draft.chat.user, draft.chat.household ]
    assert_equal [ "meeting_part", users(:head) ], [ draft.use.purpose, draft.use.user ]
    assert_equal [ draft.id ], enqueued_jobs.last["arguments"]
  end

  test "draft refuses at 15 uses today in the person's time zone, and allows again on a new day" do
    head = users(:head)
    head.update!(time_zone: "Pacific Time (US & Canada)")
    head.accept_ai_terms(understood: "1")
    zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
    part = meeting_parts(:head_conversation)
    travel_to zone.local(2026, 11, 16, 23, 0)
    15.times { Ai::Use.create!(user: head, purpose: "meeting_part") }

    refused = nil
    assert_no_difference [ -> { MeetingPart::Draft.count }, -> { Chat.count }, -> { Ai::Use.count } ] do
      assert_no_enqueued_jobs { refused = part.draft(kind: "outline", request: nil, by: head) }
    end
    assert refused.errors.added?(:base, :limit)

    # 8:01 am UTC on the 17th, and just past midnight in California.
    travel_to zone.local(2026, 11, 17, 0, 1)
    assert_predicate part.draft(kind: "outline", request: nil, by: head), :persisted?
  end

  test "draft doesn't count personal study's uses toward meeting parts" do
    users(:head).accept_ai_terms(understood: "1")
    15.times { Ai::Use.create!(user: users(:head), purpose: "personal_study") }

    assert_predicate meeting_parts(:head_conversation).draft(kind: "outline", request: nil, by: users(:head)), :persisted?
  end

  test "draft refuses without the AI terms, for a child, and on someone else's part" do
    users(:eli).accept_ai_terms(understood: "1")
    users(:spouse).accept_ai_terms(understood: "1")

    assert_no_difference [ -> { MeetingPart::Draft.count }, -> { Ai::Use.count } ] do
      assert_no_enqueued_jobs do
        [ [ :head_conversation, :head ], [ :eli_conversation, :eli ], [ :head_conversation, :spouse ] ].each do |part, user|
          assert meeting_parts(part).draft(kind: "outline", request: nil, by: users(user)).errors.added?(:base, :not_allowed), "expected #{user} on #{part} to be refused"
        end
      end
    end
  end

  # Two requests at once can't both take the 15th: the count runs after the person's row is locked, in the same
  # transaction as the insert, so the second waits for the first to commit and then counts its use.
  test "two requests racing for the last one: the count and the insert run under the person's lock" do
    users(:head).accept_ai_terms(understood: "1")
    14.times { Ai::Use.create!(user: users(:head), purpose: "meeting_part") }
    part = meeting_parts(:head_conversation)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| queries << payload[:sql] }

    part.draft(kind: "outline", request: nil, by: users(:head))
    ActiveSupport::Notifications.unsubscribe(subscriber)

    lock = queries.index { it.match?(/FROM "users" .* FOR UPDATE/) }
    count = queries.index { it.match?(/SELECT COUNT\(\*\) FROM "ai_uses"/) }
    insert = queries.index { it.start_with?('INSERT INTO "meeting_part_drafts"') }
    release = queries.index { it.match?(/RELEASE SAVEPOINT/) }
    assert_operator lock, :<, count
    assert_operator count, :<, insert
    assert_operator insert, :<, release
    assert part.draft(kind: "outline", request: nil, by: users(:head)).errors.added?(:base, :limit), "the next request finds the 15th taken"
  end

  test "destroying a part destroys its drafts and their chats, and keeps today's uses, so it doesn't give requests back" do
    part = meeting_parts(:head_conversation)
    draft = meeting_part_draft(part, status: "drafted")

    part.destroy!

    assert_not MeetingPart::Draft.exists?(draft.id)
    assert_not Chat.exists?(draft.chat_id)
    assert_nil Ai::Use.find(draft.use.id).meeting_part_draft_id
    assert_equal 14, users(:head).part_drafts_left_today
  end
end
