require "test_helper"

class Members::PersonalStudiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @study = users(:eli).personal_studies.create!(title: "How did life begin?")
    @study.with_lock { @study.start_note }.update!(body: "<p>Ask about Genesis 1.</p>")
    @study.tag_with("creation", by: users(:eli))
    personal_study_question(@study, prompt: "Who made the animals?", status: "answered",
      answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah made them (Genesis 1:24)." ], "next_questions" => [ "Why?" ] },
      sources: [ { "url" => "https://www.jw.org/en/bible-teachings/questions/creation/", "title" => "Creation" } ])
    memberships(:eli_in_home).grant_study_ai(by: users(:head))
  end

  test "an allowed head sees the list and a study with its tags, read-only" do
    sign_in identities(:head)

    get household_member_personal_studies_path(household_id: households(:home), member_id: memberships(:eli_in_home))

    assert_response :success
    assert_select "h1", text: "Eli Child's personal study"
    assert_select "a[href=?]", household_member_personal_study_path(household_id: households(:home), member_id: memberships(:eli_in_home), id: @study), text: "How did life begin?"
    assert_select ".Label", text: "#creation"

    get household_member_personal_study_path(household_id: households(:home), member_id: memberships(:eli_in_home), id: @study)

    assert_response :success
    assert_select "h1", text: "How did life begin?"
    assert_select ".Label", text: "#creation"
    assert_select "p", text: "Who made the animals?"
    assert_select "p", text: /Jehovah made them/
    assert_select "a[href=?]", "https://www.jw.org/en/bible-teachings/questions/creation/"
    assert_select "section[aria-labelledby=study-note]", text: /Ask about Genesis 1/
    assert_select "main form", count: 0
    assert_select "main button", count: 0
    assert_select "[data-bookmark-key]", count: 0
    assert_select "section[aria-labelledby=study-scriptures]", count: 0
  end

  test "a study still being answered shows that it's answering, with no Stop" do
    personal_study_question(@study, prompt: "What about the stars?")
    sign_in identities(:head)

    get household_member_personal_study_path(household_id: households(:home), member_id: memberships(:eli_in_home), id: @study)

    assert_response :success
    assert_select "p", text: "Answering…"
    assert_select "main turbo-cable-stream-source", count: 0
  end

  test "no studies yet" do
    @study.destroy!
    sign_in identities(:head)

    get household_member_personal_studies_path(household_id: households(:home), member_id: memberships(:eli_in_home))

    assert_select "h2", text: "No studies yet"
  end

  # Each request signs in again: a 404's response doesn't carry the test sign-in's session on.
  test "others get 404: an adult, the child and another household's head" do
    %i[ spouse eli outsider ].each do |identity|
      [ household_member_personal_studies_path(household_id: households(:home), member_id: memberships(:eli_in_home)),
        household_member_personal_study_path(household_id: households(:home), member_id: memberships(:eli_in_home), id: @study) ].each do |path|
        sign_in identities(identity)
        get path
        assert_response :not_found, "expected #{identity} to get a 404 on #{path}"
      end
    end
  end

  test "a head gets 404 for a study that isn't the child's, an adult's studies, and once the grant is off" do
    sign_in identities(:head)
    get household_member_personal_study_path(household_id: households(:home), member_id: memberships(:eli_in_home), id: personal_studies(:spouse_ransom))
    assert_response :not_found

    sign_in identities(:head)
    get household_member_personal_studies_path(household_id: households(:home), member_id: memberships(:spouse_in_home))
    assert_response :not_found

    memberships(:eli_in_home).revoke_study_ai
    sign_in identities(:head)
    get household_member_personal_study_path(household_id: households(:home), member_id: memberships(:eli_in_home), id: @study)
    assert_response :not_found
  end
end
