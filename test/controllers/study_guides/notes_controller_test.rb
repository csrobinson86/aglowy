require "test_helper"

# Keep in Notes: a week's study guide kept as one of the person's own notes, then opened there
# (docs/design/study-guide.md, Pages and routes, Keep in Notes). Hannah's guide for the week of 9 November has the talk
# and the weekend overview (study_guide_parts.yml); it's Tuesday of that week.
class StudyGuides::NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @user = users(:head)
    @guide = study_guides(:head_nov_9)
    travel_to Time.utc(2026, 11, 10, 16)
    sign_in identities(:head)
  end

  test "create makes the person's note titled with the week, with both meetings, and opens it" do
    assert_difference(-> { @user.personal_notes.count }, 1) { keep "2026-11-09" }

    note = @user.personal_notes.find_by!(title: "Study guide · Week of November 9")
    assert_redirected_to household_personal_note_path(household_id: @home, id: note)
    assert_equal "Kept in Notes.", flash[:notice]
    text = note.body.to_plain_text
    assert_includes text, "Midweek meeting"
    assert_includes text, "Jehovah Keeps His Word"
    assert_includes text, "The talk shows that Jehovah's warnings came true, and so will his promises."
    assert_includes text, "Main points"
    assert_includes text, "Jerusalem was warned many times before it fell."
    assert_includes text, "Weekend meeting"
    assert_includes text, "The Watchtower Study is about patience at home."
    assert_includes text, "Patient"
    assert_includes text, "He gives people time to change."
  end

  test "every part's rows are kept, and every ref is a scripture link, a whole chapter too" do
    @guide.parts.create!(step: "congregation_bible_study", content: {
      "title" => "Jehovah Is Near", "summary" => "Jehovah supports the crushed.",
      "notes" => [ { "paragraphs" => "1–3", "text" => "Everyone faces loss.", "ref" => "Psalm 23" } ],
      "jehovah" => [ { "text" => "He is close to the brokenhearted.", "ref" => "Psalm 34:18" } ],
      "comments" => [ { "paragraph" => "5", "text" => "I can lean on him." } ] })

    keep "2026-11-09"

    note = kept_note
    text = note.body.to_plain_text
    assert_includes text, "Notes"
    assert_includes text, "¶1–3: Everyone faces loss."
    assert_includes text, "About Jehovah"
    assert_includes text, "Comment ideas"
    assert_includes text, "¶5: I can lean on him."
    assert_equal [ "Lamentations 1:18", "Psalm 23", "Psalm 34:18" ], note.scripture_references.map(&:to_s)
  end

  test "every field is escaped" do
    @guide.parts.find_by!(step: "talk").update!(content: {
      "title" => "<i>Keep</i> Hoping", "summary" => "Talk about <b>hope</b>.",
      "points" => [ { "text" => "<script>alert(1)</script>Pray.", "ref" => "Lamentations 1:18" } ] })

    keep "2026-11-09"

    note = kept_note
    text = note.body.to_plain_text
    assert_includes text, "<i>Keep</i> Hoping"
    assert_includes text, "Talk about <b>hope</b>."
    assert_includes text, "<script>alert(1)</script>Pray."
    fragment = note.body.body.fragment
    assert_empty fragment.find_all("i, b, script")
  end

  test "the children's Get ready cards aren't kept" do
    @home.enable_meeting_helper(by: @user)
    @home.enable_meeting_prep(by: @user)

    keep "2026-11-09"

    text = kept_note.body.to_plain_text
    assert_includes text, "Jehovah Keeps His Word"
    assert_not_includes text, "Get ready"
    assert_not_includes text, "Tell Jehovah when I feel sad."
  end

  test "keeping it twice makes two notes, each the person's own" do
    assert_difference(-> { @user.personal_notes.count }, 2) { 2.times { keep "2026-11-09" } }

    assert_equal 2, @user.personal_notes.where(title: "Study guide · Week of November 9").count
  end

  test "another person's week is a 404" do
    sign_in identities(:spouse)

    assert_no_difference(-> { PersonalNote.count }) { keep "2026-11-09" }

    assert_response :not_found
  end

  test "a week with no guide is a 404, and so is a date that isn't one" do
    # A 404 doesn't save the session, so each request signs in again.
    %w[ 2026-11-16 not-a-date ].each do |week_of|
      sign_in identities(:head)
      assert_no_difference(-> { PersonalNote.count }) { keep week_of }

      assert_response :not_found, "expected #{week_of} to be a 404"
    end
  end

  test "a child membership is a 404, even with a guide of their own" do
    users(:eli).study_guides.create!(week_of: "2026-11-09")
    sign_in identities(:eli)

    assert_no_difference(-> { PersonalNote.count }) { keep "2026-11-09" }

    assert_response :not_found
  end

  private
    def keep(week_of)
      post household_study_guide_note_path(household_id: @home, study_guide_week_of: week_of)
    end

    def kept_note
      @user.personal_notes.find_by!(title: "Study guide · Week of November 9")
    end
end
