require "test_helper"

class PersonalStudyTest < ActiveSupport::TestCase
  test "title is 1 to 120 characters" do
    study = users(:head).personal_studies.new

    [ "", "   ", "x" * 121 ].each do |title|
      study.title = title
      assert_not study.valid?, "expected #{title.inspect} to be refused"
      assert study.errors[:title].any?
    end

    [ "x", "x" * 120 ].each do |title|
      study.title = title
      assert study.valid?, "expected a #{title.length}-character title to be valid"
    end
  end

  test "a title has its spaces squished" do
    assert_equal "The ransom", users(:head).personal_studies.new(title: "  The   ransom ").title
  end

  test "notes are encrypted at rest" do
    study = personal_studies(:head_suffering)
    study.update!(notes: "<p>Rebellion in Eden, not God's doing</p>")

    raw = ActionText::RichText.connection.select_value(ActionText::RichText.where(record: study, name: "notes").select(:body).to_sql)

    assert_not_includes raw, "Rebellion in Eden"
    assert_includes study.reload.notes.to_plain_text, "Rebellion in Eden, not God's doing"
  end

  test "link_scriptures links the references typed in the notes" do
    study = personal_studies(:head_suffering)
    study.notes = "<p>Read Genesis 3:1-6 again</p>"

    study.link_scriptures
    study.save!

    assert_equal [ Bible::Reference.find("1:3:1-6") ], study.reload.notes.body.attachables
  end

  test "notes can only hold scripture links" do
    study = personal_studies(:head_suffering)
    study.notes = "<p>A cat</p>#{remote_image_attachment}"

    assert_not study.valid?
    assert_equal [ "can only link scriptures" ], study.errors[:notes]
  end

  test "matching finds by title, by collection name and by tag, and not by note text" do
    head = users(:head)
    suffering, kindness, daniel = personal_studies(:head_suffering, :head_kindness, :head_daniel)
    daniel.tag_with("Prophecy", by: head)
    kindness.update!(notes: "<p>The neighborly Samaritan</p>")

    assert_equal [ suffering ], head.personal_studies.matching("suffering").to_a
    assert_equal [ kindness ], head.personal_studies.matching("preparing a").to_a
    assert_equal [ daniel ], head.personal_studies.matching("#prophecy").to_a
    assert_empty head.personal_studies.matching("Samaritan")
  end

  test "matching treats % and _ as plain characters" do
    assert_empty users(:head).personal_studies.matching("%")
    assert_empty users(:head).personal_studies.matching("_")
  end

  test "recent_first: last asked first, then the most recently updated" do
    suffering, kindness, daniel = personal_studies(:head_suffering, :head_kindness, :head_daniel)
    suffering.update_columns(last_asked_at: 1.day.ago, updated_at: 3.days.ago)
    kindness.update_columns(last_asked_at: nil, updated_at: 1.hour.ago)
    daniel.update_columns(last_asked_at: nil, updated_at: 2.days.ago)

    assert_equal [ suffering, kindness, daniel ], users(:head).personal_studies.recent_first.to_a
  end

  test "only its owner can tag it" do
    study = personal_studies(:head_suffering)

    assert study.taggable_by?(users(:head))
    assert_not study.taggable_by?(users(:spouse))
    assert_raises(ActiveRecord::RecordInvalid) { study.tag_with("ministry", by: users(:spouse)) }
  end

  test "deleting a collection nullifies the studies' collection_id" do
    study = personal_studies(:head_suffering)

    collections(:head_bible_questions).destroy!

    assert_nil study.reload.collection_id
  end

  test "deleting a study deletes its taggings and notes" do
    study = personal_studies(:head_suffering)
    study.tag_with("ministry", by: users(:head))
    study.update!(notes: "<p>Gone with it</p>")

    assert_difference -> { Tagging.count } => -1, -> { ActionText::RichText.count } => -1 do
      study.destroy!
    end
  end

  test "deleting the person deletes their studies and collections" do
    newcomer = users(:newcomer)
    newcomer.personal_studies.create!(title: "Prayer", collection: newcomer.collections.add(name: "Bible questions"))

    assert_difference -> { PersonalStudy.count } => -1, -> { Collection.count } => -1 do
      newcomer.destroy!
    end
  end

  test "creating a study creates its personal study chat; deleting it deletes the chat" do
    study = users(:spouse).personal_studies.create!(title: "Prayer")

    assert_equal "personal_study", study.chat.purpose
    assert_equal users(:spouse), study.chat.user
    assert_nil study.chat.household

    assert_difference -> { Chat.count }, -1 do
      study.destroy!
    end
  end

  test "sources: every page across the study's answers, once each, never a question still asking or refused" do
    study = personal_studies(:head_suffering)
    suffering = { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" }
    eden = { "url" => "https://wol.jw.org/en/wol/d/r1/lp-e/2017283", "title" => "The Issue Raised in Eden" }
    personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "One." ] }, sources: [ suffering, eden ])
    personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "Two." ] }, sources: [ suffering ])
    personal_study_question(study)

    assert_equal [ suffering, eden ], study.reload.sources
  end

  # Exactly the scripture links the answers show (docs/design/bookmarks.md, PersonalStudy#scripture_references): a
  # chapter alone stays text, and a question still asking or refused adds none.
  test "scripture_references lists each reference once, in order, from answered questions only" do
    study = personal_studies(:head_suffering)
    personal_study_question(study, status: "answered", answer: { "paragraphs" => [ "Sin spread (Romans 5:12), see Genesis 3:1-6.", "Psalm 23 comforts." ] })
    personal_study_question(study, status: "answered", answer: { "not_found" => true, "paragraphs" => [ "No one knows the day (Matthew 24:36); Romans 5:12 again." ] })
    personal_study_question(study, status: "off_topic", answer: { "paragraphs" => [ "John 3:16" ] })
    personal_study_question(study, answer: { "paragraphs" => [ "Job 1:9-11" ] })

    assert_equal [ "Romans 5:12", "Genesis 3:1-6", "Matthew 24:36" ], study.reload.scripture_references.map(&:to_s)
  end

  test "scripture_references is empty with no answers" do
    assert_empty personal_studies(:head_kindness).scripture_references
  end

  test "conversation: the questions asked, oldest first, never one ask refused" do
    users(:head).accept_ai_terms(understood: true)
    study = personal_studies(:head_suffering)
    asked = personal_study_question(study)
    study.questions.load

    refused = study.ask(" ", by: users(:head))

    assert_not refused.persisted?
    assert_equal [ asked ], study.conversation
  end

  test "database: a study needs a chat" do
    assert_raises(ActiveRecord::NotNullViolation) { personal_studies(:head_suffering).update_column(:chat_id, nil) }
  end

  test "database: two studies can't share a chat" do
    assert_raises(ActiveRecord::RecordNotUnique) { personal_studies(:head_daniel).update_column(:chat_id, personal_studies(:head_suffering).chat_id) }
  end

  test "database: a blank title raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      PersonalStudy.insert!({ user_id: users(:head).id, chat_id: new_chat.id, title: "" })
    end
  end

  test "database: a title over 120 characters raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) do
      PersonalStudy.insert!({ user_id: users(:head).id, chat_id: new_chat.id, title: "x" * 121 })
    end
  end

  test "database: a study needs a person" do
    assert_raises(ActiveRecord::NotNullViolation) do
      PersonalStudy.insert!({ user_id: nil, chat_id: new_chat.id, title: "No one's" })
    end
  end

  test "tags_for: an allowed head sees the child's tags on a study; a head without a grant, an adult and another household don't" do
    study = eli_study_tagged("creation")
    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert_equal [ "creation" ], study.tags_for(users(:head), membership: memberships(:head_in_home)).map(&:name)
    assert_empty study.tags_for(users(:spouse), membership: memberships(:spouse_in_home))
    assert_empty study.tags_for(users(:grandparent), membership: memberships(:grandparent_in_parents))
    assert_empty study.tags_for(users(:head), membership: nil)

    memberships(:eli_in_home).revoke_study_ai

    assert_empty study.tags_for(users(:head), membership: memberships(:head_in_home))
  end

  test "tags_for: the child's meeting note stays empty for an allowed head" do
    eli_study_tagged("creation")
    memberships(:eli_in_home).grant_study_ai(by: users(:head))
    note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    note.tag_with("creation", by: users(:eli))

    assert_empty note.tags_for(users(:head), membership: memberships(:head_in_home))
    assert_equal [ "creation" ], note.tags_for(users(:eli), membership: memberships(:eli_in_home)).map(&:name)
  end

  private
    def eli_study_tagged(name)
      users(:eli).personal_studies.create!(title: "How did life begin?").tap { it.tag_with(name, by: users(:eli)) }
    end

    def new_chat
      Chat.create!(user: users(:head), purpose: "personal_study")
    end
end
