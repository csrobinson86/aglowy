require "test_helper"

# The study's note edited in place beside the conversation (docs/design/personal-study.md, The study page: Study note).
class PersonalStudies::NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @study = personal_studies(:head_suffering)
  end

  test "create makes the study's one note and opens it for editing; a second create finds the same note" do
    sign_in identities(:head)

    assert_difference -> { PersonalNote.count } => 1 do
      post household_personal_study_note_path(household_id: @home, personal_study_id: @study)
      post household_personal_study_note_path(household_id: @home, personal_study_id: @study)
    end

    assert_redirected_to edit_household_personal_study_note_path(household_id: @home, personal_study_id: @study)
    assert_equal @study, @study.reload.note.personal_study
  end

  test "create after Save to note reuses the note the answer went into" do
    note = answered_question.save_to_note
    sign_in identities(:head)

    assert_no_difference -> { PersonalNote.count } do
      post household_personal_study_note_path(household_id: @home, personal_study_id: @study)
    end

    assert_equal note, @study.reload.note
  end

  test "edit shows the editor in the panel's frame with the note's version, Save note, Cancel and where the rest is" do
    note = @study.with_lock { @study.start_note }
    note.update!(body: "<p>Start with Job.</p>")
    sign_in identities(:head)

    get edit_household_personal_study_note_path(household_id: @home, personal_study_id: @study)

    assert_response :success
    assert_select "turbo-frame#note_panel_personal_study_#{@study.id} form[action=?]", household_personal_study_note_path(household_id: @home, personal_study_id: @study) do
      assert_select "input[type=hidden][name='personal_note[base]'][value=?]", note.base
      assert_select "lexxy-editor[name='personal_note[body]'][value*='Start with Job.']"
      assert_select "button[type=submit]", "Save note"
      assert_select "input[name='personal_note[title]']", false
    end
    assert_select "turbo-frame a", text: "Cancel"
    assert_text_in_body "Title, color and tags are in Notes."
  end

  test "edit with no note yet: 404" do
    sign_in identities(:head)

    get edit_household_personal_study_note_path(household_id: @home, personal_study_id: @study)

    assert_response :not_found
  end

  test "update saves the body only, links its scriptures, and returns to the study" do
    note = @study.with_lock { @study.start_note }
    sign_in identities(:head)

    patch household_personal_study_note_path(household_id: @home, personal_study_id: @study),
      params: { personal_note: { base: note.base, body: "<p>Read Romans 5:12.</p>", title: "Renamed" } }

    assert_redirected_to household_personal_study_path(household_id: @home, id: @study)
    note.reload
    assert_equal "Why does Jehovah allow suffering?", note.title
    assert_includes note.body.to_plain_text, "Read Romans 5:12."
    assert_equal [ Bible::Reference.find("45:5:12") ], note.body.body.attachables
  end

  test "update with a stale base writes nothing and shows the note as it is now, with What you wrote: 409" do
    note = @study.with_lock { @study.start_note }
    stale = note.base
    second = answered_question
    travel 1.second do
      second.save_to_note
    end
    sign_in identities(:head)

    assert_no_changes -> { note.reload.updated_at } do
      patch household_personal_study_note_path(household_id: @home, personal_study_id: @study),
        params: { personal_note: { base: stale, body: "<p>My own words</p>" } }
    end

    assert_response :conflict
    assert_select ".Banner--warning", text: /This note changed after you started editing/
    assert_select "input[type=hidden][name='personal_note[base]'][value=?]", note.reload.base
    assert_select "lexxy-editor[name='personal_note[body]'][value*='Jehovah never causes suffering']"
    assert_select "section[aria-labelledby=what-you-wrote]", text: /My own words/
    assert_not_includes note.body.to_plain_text, "My own words"
  end

  test "update with anything but scripture links writes nothing and shows the editor again: 422" do
    note = @study.with_lock { @study.start_note }
    sign_in identities(:head)

    patch household_personal_study_note_path(household_id: @home, personal_study_id: @study),
      params: { personal_note: { base: note.base, body: "<p>A cat</p>#{remote_image_attachment}" } }

    assert_response :unprocessable_content
    assert_select ".FormControl-inlineValidation", text: /can only link scriptures/
    assert_select ".Banner", false
    assert_select "turbo-frame#note_panel_personal_study_#{@study.id} lexxy-editor[name='personal_note[body]']"
    assert_not_includes note.reload.body.to_plain_text, "A cat"
  end

  test "another person's study: 404" do
    spouse_study = personal_studies(:spouse_ransom)
    sign_in identities(:head)

    post household_personal_study_note_path(household_id: @home, personal_study_id: spouse_study)

    assert_response :not_found
    assert_nil spouse_study.reload.note
  end

  test "a head who can read a child's study gets a 404 on create, edit and update" do
    child_study = users(:eli).personal_studies.create!(title: "How did life begin?")
    note = child_study.with_lock { child_study.start_note }
    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    [
      -> { post household_personal_study_note_path(household_id: @home, personal_study_id: child_study) },
      -> { get edit_household_personal_study_note_path(household_id: @home, personal_study_id: child_study) },
      -> { patch household_personal_study_note_path(household_id: @home, personal_study_id: child_study), params: { personal_note: { base: note.base, body: "<p>Mine now</p>" } } }
    ].each do |request|
      sign_in identities(:head) # a 404 doesn't keep the session
      request.call
      assert_response :not_found
    end

    assert_not_includes note.reload.body.to_plain_text, "Mine now"
  end

  private
    def answered_question
      personal_study_question(@study, status: "answered", answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering." ], "next_questions" => [] })
    end

    def assert_text_in_body(text)
      assert_includes response.body, text
    end
end
