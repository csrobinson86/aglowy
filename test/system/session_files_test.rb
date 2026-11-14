require "application_system_test_case"

class SessionFilesTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
  end

  test "upload a PDF on the session page and open it" do
    study_session = family_study_sessions(:weekly_next)
    visit household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)

    assert_text "Drag your own PDFs or images here, or choose files"
    assert_text "Up to 25 MB each"
    assert_accessible
    attach_file "choose files", file_fixture("study-guide.pdf"), make_visible: true

    assert_text "1 file added."
    within ".Box-row", text: "study-guide.pdf" do
      assert_selector "svg.octicon-file"
      assert_text "191 Bytes"
    end
    assert_accessible
    capture_screens("session-files", scroll_to: ".file-drop")

    file = window_opened_by { click_link "study-guide.pdf" }
    within_window(file) do
      assert_current_path %r{\A/rails/active_storage/disk/.+/study-guide.pdf}
    end
  end

  test "a refused file shows its own error, and the good one can still be added" do
    study_session = family_study_sessions(:weekly_next)
    visit household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)

    attach_file "choose files", [ file_fixture("photo.png"), file_fixture("program.exe") ], make_visible: true

    within "li", text: "program.exe" do
      assert_text "Must be a PDF or an image (PNG, JPEG, GIF, WebP or HEIC)."
    end
    assert_accessible
    capture_screens("session-files-refused", scroll_to: ".file-drop")
    click_on "Add files"

    assert_text "1 file added."
    assert_link "photo.png"
    assert_no_link "program.exe"
  end

  test "drop a file on the schedule form and find it on the session" do
    visit new_household_family_study_url(household_id: households(:home))

    fill_in "What will you study?", with: "Proverbs 3"
    fill_in "Date", with: 7.days.from_now.to_date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    find(".file-drop").drop(file_fixture("study-guide.pdf"))

    within(".file-drop") { assert_selector "progress[value='100']", visible: :all }
    assert_accessible
    capture_screens("schedule-study-files", scroll_to: ".file-drop")
    click_on "Schedule study"

    assert_text "Your family study is scheduled."
    click_on "Proverbs 3"

    assert_link "study-guide.pdf"
  end
end
