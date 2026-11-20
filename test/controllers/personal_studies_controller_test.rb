require "test_helper"

class PersonalStudiesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @home = households(:home)
    @study = personal_studies(:head_suffering)
  end

  test "index lists my studies, my collections for studies with their counts, and my tags" do
    @study.tag_with("ministry", by: users(:head))
    sign_in identities(:head)

    get household_personal_studies_path(household_id: @home)

    assert_response :success
    assert_select "title", "Personal study · The Head Family · Aglowy"
    assert_select "h1", "Personal study"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Personal study"
    assert_select "main .Box-row", count: 3
    assert_select "main .Box-row a[href=?]", household_personal_study_path(household_id: @home, id: @study), text: @study.title
    assert_select "main", text: /The ransom/, count: 0
    assert_select "nav[aria-label='Collections'] a[aria-current='page']", text: /All studies\s+3/
    assert_select "nav[aria-label='Collections'] a", text: /Bible questions/ do |link|
      assert_select link, "svg[aria-label='Shared with Notes']"
    end
    assert_select "nav[aria-label='Collections'] a", text: /Preparing a talk\s+1/
    assert_select "nav[aria-label='Collections'] a", text: /Quick references/, count: 0
    assert_select "main", text: /Also used in Notes/
    assert_select "nav[aria-label='My tags'] a[href=?]", household_personal_studies_path(household_id: @home, tag: "ministry"), text: /#ministry\s+2/
    assert_select "main a.Label[href=?]", household_tag_path(household_id: @home, name: "ministry")
  end

  test "index with no studies shows the empty state" do
    sign_in identities(:eli)

    get household_personal_studies_path(household_id: @home)

    assert_select ".blankslate h2", "No studies yet."
    assert_select ".blankslate p", "Start one with a question or a topic you'd like to research."
    assert_select ".blankslate a[href=?]", new_household_personal_study_path(household_id: @home), text: "New study"
    assert_select "main", text: /Also used in Notes/, count: 0
  end

  test "index filters by collection" do
    sign_in identities(:head)

    get household_personal_studies_path(household_id: @home, collection: collections(:head_talks).id)

    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row", text: /Talk: Showing kindness/
    assert_select "nav[aria-label='Collections'] a[aria-current='page']", text: /Preparing a talk/
  end

  test "index filtered by another person's collection, or a notes-only one, shows nothing" do
    sign_in identities(:head)

    [ collections(:spouse_ministry), collections(:head_quick_references) ].each do |collection|
      get household_personal_studies_path(household_id: @home, collection: collection.id)

      assert_select "main .Box-row", count: 0
      assert_select ".blankslate h2", "No studies match"
    end
  end

  test "index filters by tag" do
    personal_studies(:head_daniel).tag_with("prophecy", by: users(:head))
    sign_in identities(:head)

    get household_personal_studies_path(household_id: @home, tag: "Prophecy")

    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row", text: /The meaning of Daniel 2/
    assert_select "a[aria-label='Remove filter #prophecy'][href=?]", household_personal_studies_path(household_id: @home)
    assert_select "nav[aria-label='My tags'] a[aria-current='page']", text: /#prophecy/
  end

  test "index filters by q, together with a collection" do
    sign_in identities(:head)

    get household_personal_studies_path(household_id: @home, q: "a")
    assert_select "main .Box-row", count: 3

    get household_personal_studies_path(household_id: @home, q: "kindness")
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row", text: /Talk: Showing kindness/
    assert_select "input[name=q][value=kindness]"

    get household_personal_studies_path(household_id: @home, q: "kindness", collection: collections(:head_bible_questions).id)
    assert_select "main .Box-row", count: 0
    assert_select "input[type=hidden][name=collection][value=?]", collections(:head_bible_questions).id
  end

  test "new, with the collection I was looking at chosen" do
    sign_in identities(:head)

    get new_household_personal_study_path(household_id: @home, collection: collections(:head_talks).id)

    assert_response :success
    assert_select "h1", "New study"
    assert_select "select[name='personal_study[collection_id]'] option[selected][value=?]", collections(:head_talks).id
    assert_select "select[name='personal_study[collection_id]'] option", text: "Quick references", count: 0
  end

  test "create a study in a collection" do
    sign_in identities(:head)

    assert_difference -> { users(:head).personal_studies.count } do
      post household_personal_studies_path(household_id: @home), params: { personal_study: { title: "Prayer", collection_id: collections(:head_talks).id } }
    end

    study = users(:head).personal_studies.find_by!(title: "Prayer")
    assert_redirected_to household_personal_study_path(household_id: @home, id: study)
    assert_equal collections(:head_talks), study.collection
  end

  test "create without a collection, and a blank title shows the form again" do
    sign_in identities(:head)

    post household_personal_studies_path(household_id: @home), params: { personal_study: { title: "Prayer", collection_id: "" } }
    assert_nil users(:head).personal_studies.find_by!(title: "Prayer").collection

    assert_no_difference -> { PersonalStudy.count } do
      post household_personal_studies_path(household_id: @home), params: { personal_study: { title: " " } }
    end
    assert_response :unprocessable_content
    assert_select "h1", "New study"
  end

  test "a blank title shows the form again with the first question kept" do
    users(:head).accept_ai_terms(understood: true)
    sign_in identities(:head)

    assert_no_enqueued_jobs do
      post household_personal_studies_path(household_id: @home), params: { personal_study: { title: " ", prompt: "Why pray?" } }
    end
    assert_response :unprocessable_content
    assert_select "textarea[name='personal_study[prompt]']", text: "Why pray?"
  end

  test "create with a first question asks it straight away" do
    users(:head).accept_ai_terms(understood: true)
    sign_in identities(:head)

    assert_enqueued_jobs(1, only: PersonalStudy::AnswerQuestionJob) do
      post household_personal_studies_path(household_id: @home), params: { personal_study: { title: "Prayer", collection_id: "", prompt: "Why does Jehovah want us to pray?" } }
    end

    study = users(:head).personal_studies.find_by!(title: "Prayer")
    assert_redirected_to household_personal_study_path(household_id: @home, id: study)
    assert_equal "Why does Jehovah want us to pray?", study.questions.sole.prompt
    assert_equal "Study started.", flash[:notice]
  end

  test "a first question refused at the day's limit leaves the study started, with the reason" do
    users(:head).accept_ai_terms(understood: true)
    30.times { Ai::Use.create!(user: users(:head), purpose: "personal_study") }
    sign_in identities(:head)

    assert_difference -> { PersonalStudy.count } do
      post household_personal_studies_path(household_id: @home), params: { personal_study: { title: "Prayer", prompt: "Why pray?" } }
    end

    assert_empty users(:head).personal_studies.find_by!(title: "Prayer").questions
    assert_equal "You've asked 30 questions today. You can ask again after midnight.", flash[:alert]
  end

  test "New study offers a first question only to someone who can ask the AI, with questions left today" do
    sign_in identities(:head)

    get new_household_personal_study_path(household_id: @home)
    assert_select "textarea[name='personal_study[prompt]']", count: 0

    users(:head).accept_ai_terms(understood: true)
    get new_household_personal_study_path(household_id: @home)
    assert_select "textarea[name='personal_study[prompt]']"
    assert_select "label", text: "First question"

    30.times { Ai::Use.create!(user: users(:head), purpose: "personal_study") }
    get new_household_personal_study_path(household_id: @home)
    assert_select "textarea[name='personal_study[prompt]']", count: 0
  end

  test "show: the conversation, the ask box, and the study's sources once each" do
    users(:head).accept_ai_terms(understood: true)
    page = { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" }
    answer = { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "An answer." ], "next_questions" => [] }
    2.times { personal_study_question(@study, status: "answered", answer:, sources: [ page ]) }
    sign_in identities(:head)

    get household_personal_study_path(household_id: @home, id: @study)

    assert_select ".study-question", count: 2
    assert_select ".Subhead", text: /· 2 questions · 1 page linked/
    assert_select "label", text: /\AAsk a follow-up/
    assert_select "section[aria-labelledby=study-sources] li a[href=?]", page["url"], count: 1
    assert_select "section[aria-labelledby=study-sources]", text: /Titles and links only. Open a page to read it on jw.org./
  end

  # docs/design/bookmarks.md, The bookmark button: beside each page in Pages used and Sources in this study, with the
  # person's bookmarks read once for the page.
  test "show: a bookmark button beside each page, filled where it's saved, from one read of the bookmarks" do
    saved = { "url" => bookmarks(:head_suffering_article).url, "title" => "Why Does God Allow Suffering?" }
    other = { "url" => "https://wol.jw.org/en/wol/d/r1/lp-e/2017283", "title" => "The Issue Raised in Eden" }
    answer = { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "An answer." ], "next_questions" => [] }
    personal_study_question(@study, status: "answered", answer:, sources: [ saved, other ])
    sign_in identities(:head)

    assert_queries_match(/FROM "bookmarks"/, count: 1) do
      get household_personal_study_path(household_id: @home, id: @study)
    end

    assert_select "ul[aria-label='Pages used'] button[aria-pressed=true][aria-label=?]", "Remove bookmark: Why Does God Allow Suffering?"
    assert_select "ul[aria-label='Pages used'] button[aria-pressed=false][aria-label=?]", "Bookmark: The Issue Raised in Eden"
    assert_select "section[aria-labelledby=study-sources] button[aria-pressed=true][aria-label=?]", "Remove bookmark: Why Does God Allow Suffering?"
    assert_select "section[aria-labelledby=study-sources] button[aria-pressed=false][aria-label=?]", "Bookmark: The Issue Raised in Eden"
  end

  # docs/design/bookmarks.md, The bookmark button: a Scriptures in this study box above Sources in this study, each
  # reference the answers link with its bookmark button.
  test "show: Scriptures in this study, above Sources in this study, a bookmark button beside each" do
    answer = { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Sin spread (Romans 5:12; Revelation 21:3, 4)." ], "next_questions" => [] }
    personal_study_question(@study, status: "answered", answer:)
    users(:head).bookmark(scripture: "66:21:3-4", source: @study)
    sign_in identities(:head)

    get household_personal_study_path(household_id: @home, id: @study)

    assert_select "section[aria-labelledby=study-scriptures]" do
      assert_select "h2", "Scriptures in this study"
      assert_select "a.scripture-link[href=?]", Bible::Reference.find("45:5:12").jw_url, text: "Romans 5:12"
      assert_select "button[aria-pressed=false][aria-label=?]", "Bookmark: Romans 5:12"
      assert_select "button[aria-pressed=true][aria-label=?]", "Remove bookmark: Revelation 21:3, 4"
      assert_select "*", text: /Each opens on jw.org, or in JW Library if it's installed./
    end
    assert_select "section[aria-labelledby=study-scriptures] ~ section[aria-labelledby=study-sources]"
  end

  test "show with no questions yet" do
    users(:head).accept_ai_terms(understood: true)
    sign_in identities(:head)

    get household_personal_study_path(household_id: @home, id: @study)

    assert_select ".study-question", count: 0
    assert_select ".Subhead", text: /questions? ·/, count: 0
    assert_select "label", text: /\AAsk a question/
    assert_select "main", text: /30 of 30 questions left today/
    assert_select "section[aria-labelledby=study-sources]", text: /The pages each answer uses show here./
  end

  test "show without the AI terms: the first-use notice in place of the ask box" do
    sign_in identities(:head)

    get household_personal_study_path(household_id: @home, id: @study)

    assert_select "h2", "Before you use AI"
    assert_select "form[action=?]", ai_acceptance_path(return_to: household_personal_study_path(household_id: @home, id: @study), not_now: false)
    assert_select "button", text: "Not now", count: 0
    assert_select "textarea[name='personal_study_question[prompt]']", count: 0
  end

  test "create in another person's collection: 404" do
    sign_in identities(:head)

    assert_no_difference -> { PersonalStudy.count } do
      post household_personal_studies_path(household_id: @home), params: { personal_study: { title: "Prayer", collection_id: collections(:spouse_ministry).id } }
    end
    assert_response :not_found
  end

  test "create in a notes-only collection shows the form again" do
    sign_in identities(:head)

    assert_no_difference -> { PersonalStudy.count } do
      post household_personal_studies_path(household_id: @home), params: { personal_study: { title: "Prayer", collection_id: collections(:head_quick_references).id } }
    end
    assert_response :unprocessable_content
    assert_select ".Banner--error", text: /Collection is only used in Notes/
  end

  test "show has the header with the tag editor, and the study's note read-only in its frame, with Open in Notes and Edit" do
    @study.tag_with("ministry", by: users(:head))
    note = @study.with_lock { @study.start_note }
    note.update!(body: "<p>Start with Job.</p>")
    sign_in identities(:head)

    get household_personal_study_path(household_id: @home, id: @study)

    assert_response :success
    assert_select "title", "#{@study.title} · The Head Family · Aglowy"
    assert_select "nav[aria-label='Breadcrumb'] a", text: "Personal study"
    assert_select "nav[aria-label='Breadcrumb'] a[href=?]", household_personal_studies_path(household_id: @home, collection: collections(:head_bible_questions).id), text: "Bible questions"
    assert_select "h1", @study.title
    assert_select "#tag_editor_personal_study_#{@study.id} a.Label", "#ministry"
    assert_select "nav[aria-label='Main'] a[aria-current='page']", "Personal study"
    assert_select "turbo-frame#note_panel_personal_study_#{@study.id} #note_personal_study_#{@study.id}.note-card--none" do
      assert_select "h2", "Study note"
      assert_select ".lexxy-content", text: /Start with Job./
      assert_select "a[href=?][data-turbo-frame=_top]", household_personal_note_path(household_id: @home, id: note), text: "Open in Notes"
      assert_select "a[href=?]", edit_household_personal_study_note_path(household_id: @home, personal_study_id: @study), text: "Edit"
      assert_select "*", text: /In Notes · Edited/
    end
    assert_select "lexxy-editor", false
    assert_select "dialog#delete-personal-study"
  end

  test "update: rename" do
    sign_in identities(:head)

    patch household_personal_study_path(household_id: @home, id: @study), params: { personal_study: { title: "Why is there suffering?" } }

    assert_redirected_to household_personal_study_path(household_id: @home, id: @study)
    assert_equal "Why is there suffering?", @study.reload.title
    assert_equal collections(:head_bible_questions), @study.collection
  end

  test "update: a title too long shows the page again with the reason" do
    sign_in identities(:head)

    patch household_personal_study_path(household_id: @home, id: @study), params: { personal_study: { title: "x" * 121 } }

    assert_response :unprocessable_content
    assert_select "h1", @study.title
    assert_select ".Banner--error", text: /Title is too long/
  end

  test "update: move to another collection, and out of any" do
    sign_in identities(:head)

    patch household_personal_study_path(household_id: @home, id: @study), params: { personal_study: { collection_id: collections(:head_talks).id } }
    assert_equal collections(:head_talks), @study.reload.collection

    patch household_personal_study_path(household_id: @home, id: @study), params: { personal_study: { collection_id: "" } }
    assert_nil @study.reload.collection
  end

  test "update: moving to another person's collection is a 404" do
    sign_in identities(:head)

    patch household_personal_study_path(household_id: @home, id: @study), params: { personal_study: { collection_id: collections(:spouse_ministry).id } }

    assert_response :not_found
    assert_equal collections(:head_bible_questions), @study.reload.collection
  end

  test "destroy" do
    sign_in identities(:head)

    assert_difference -> { PersonalStudy.count }, -1 do
      delete household_personal_study_path(household_id: @home, id: @study)
    end
    assert_redirected_to household_personal_studies_path(household_id: @home)
  end

  test "another person's study: 404 for show, update, destroy and tagging" do
    study = personal_studies(:spouse_ransom)

    [
      -> { get household_personal_study_path(household_id: @home, id: study) },
      -> { patch household_personal_study_path(household_id: @home, id: study), params: { personal_study: { title: "Mine now" } } },
      -> { delete household_personal_study_path(household_id: @home, id: study) },
      -> { post household_personal_study_taggings_path(household_id: @home, personal_study_id: study), params: { name: "ministry" }, as: :turbo_stream },
      -> { delete household_personal_study_tagging_path(household_id: @home, personal_study_id: study, id: tags(:head_ministry)), as: :turbo_stream }
    ].each do |request|
      sign_in identities(:head) # a 404 doesn't keep the session
      request.call
      assert_response :not_found
    end

    assert_equal "The ransom", study.reload.title
    assert_empty study.tags
  end

  test "a non-member: 404" do
    sign_in identities(:outsider)

    get household_personal_studies_path(household_id: @home)

    assert_response :not_found
  end

  test "a child can create and edit their own" do
    sign_in identities(:eli)

    post household_personal_studies_path(household_id: @home), params: { personal_study: { title: "Creation" } }
    study = users(:eli).personal_studies.find_by!(title: "Creation")
    assert_redirected_to household_personal_study_path(household_id: @home, id: study)

    get household_personal_study_path(household_id: @home, id: study)
    assert_response :success

    patch household_personal_study_path(household_id: @home, id: study), params: { personal_study: { title: "How life began" } }
    assert_redirected_to household_personal_study_path(household_id: @home, id: study)
    assert_equal "How life began", study.reload.title

    post household_personal_study_taggings_path(household_id: @home, personal_study_id: study), params: { name: "creation" }, as: :turbo_stream
    assert_response :success
    assert_equal [ "creation" ], study.tags.map(&:name)
  end

  test "the owner tags a study and removes the tag" do
    sign_in identities(:head)

    post household_personal_study_taggings_path(household_id: @home, personal_study_id: @study), params: { name: "Ministry" }, as: :turbo_stream
    assert_select "turbo-stream[action=replace][target='tag_editor_personal_study_#{@study.id}'] template a.Label", text: "#ministry"

    delete household_personal_study_tagging_path(household_id: @home, personal_study_id: @study, id: tags(:head_ministry)), as: :turbo_stream
    assert_empty @study.tags.reload
  end
end
